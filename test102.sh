#!/usr/bin/env bash
# ==============================================================================
# СЕТЕВАЯ ДИАГНОСТИКА А1 — Версия для Linux / macOS
# ==============================================================================
# Используются ТОЛЬКО встроенные системные утилиты (без sudo).
# Совместимость: bash 3.2+ (macOS default), bash 4+/5+ (Linux).
# Запуск: chmod +x test102.sh && ./test102.sh
# ==============================================================================

# --- Защита от запуска через sh (dash/ash и др.) ---
# Скрипт использует bash-специфичные фичи (/dev/tcp, BASH_SOURCE, &>/dev/null и др.)
# При запуске через "sh test102.sh" вместо "bash test102.sh" или "./test102.sh" — всё сломается
if [ -z "$BASH_VERSION" ]; then
    echo "Ошибка: скрипт должен быть запущен через bash."
    echo "Используйте:  ./test102.sh  или  bash test102.sh"
    echo "(Не sh test102.sh)"
    exit 1
fi

# --- Маска файлов: лог содержит лицевой счёт, процессы, расширения ---
# umask 077 = создаваемые файлы будут с правами 600 (только владелец)
umask 077

# --- Глобальные параметры безопасности скрипта ---
# Не прерывать скрипт при ошибках отдельных команд (отказоустойчивость)
set +e
# Но отслеживать ошибки в пайпах (если bash >= 3)
set -o pipefail 2>/dev/null || true

# ==============================================================================
# 1. ПОДГОТОВКА ОКРУЖЕНИЯ И ПЕРЕМЕННЫХ
# ==============================================================================

# --- Определяем операционную систему ---
# uname -s возвращает "Linux" или "Darwin" (macOS)
OS_TYPE="$(uname -s)"

# --- Определяем директорию, в которой лежит скрипт ---
# BASH_SOURCE[0] содержит путь к текущему скрипту
# dirname извлекает каталог; cd + pwd даёт абсолютный путь
DIAG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Пути и константы ---
LOG_FILE="${DIAG_DIR}/A1.txt"           # Файл отчёта
SUPPORT_EMAIL="support150@a1.by"        # Email для отправки отчёта

# --- Флаг: удалось ли замерить MTR/трассировку ---
# Нужен для итогов: если утилиты не установлены — пишем "не удалось измерить"
MTR_AVAILABLE=0

# --- Подавляем локализацию в выводе системных утилит ---
# Это нужно чтобы парсить вывод команд (ping, traceroute и т.д.) на английском
export LC_ALL=C
export LANG=C

# --- Цветовые коды ANSI для вывода в терминал ---
# Используем tput если доступен, иначе raw ANSI-коды
if command -v tput &>/dev/null && tput colors &>/dev/null; then
    COLOR_RED="$(tput setaf 1)"
    COLOR_GREEN="$(tput setaf 2)"
    COLOR_YELLOW="$(tput setaf 3)"
    COLOR_CYAN="$(tput setaf 6)"
    COLOR_GRAY="$(tput setaf 8 2>/dev/null || tput setaf 7)"
    COLOR_RESET="$(tput sgr0)"
else
    COLOR_RED="\033[0;31m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_CYAN="\033[0;36m"
    COLOR_GRAY="\033[0;90m"
    COLOR_RESET="\033[0m"
fi

# ==============================================================================
# --- ФУНКЦИИ ОФОРМЛЕНИЯ И ИНСТРУМЕНТЫ ---
# ==============================================================================

# --- write_step: Печатает название текущего шага диагностики ---
# Аргументы: $1 = номер шага (напр. "1/12"), $2 = описание
write_step() {
    local num="$1" text="$2"
    # Массив иконок для каждого шага (ассоциативный массив не поддерживается в bash 3.2)
    local icons=("" "🔍" "💻" "🛠️" "🌐" "📡" "🧱" "🗺️" "🛤️" "⏱️" "📊" "🚀" "📦")
    # Извлекаем номер шага из строки вида "3/12"
    local idx="${num%%/*}"
    local icon="${icons[$idx]:-•}"
    # Дополняем текст точками до 45 символов для выравнивания
    local padded
    padded="$(printf '%-45s' "$text" | tr ' ' '.')"
    printf " %s ${COLOR_GRAY}[%s]${COLOR_RESET} %s" "$icon" "$num" "$padded"
}

# --- write_status_ok: Печатает зелёный статус [ГОТОВО] ---
write_status_ok() {
    printf " ${COLOR_GREEN}[ГОТОВО]${COLOR_RESET}\n"
}

# --- write_log_header: Записывает заголовок секции в лог-файл ---
# Аргумент: $1 = заголовок секции
write_log_header() {
    local title="$1"
    printf "\n############### [ %s ] ###############\n\n" "$title" >> "$LOG_FILE"
}

# --- write_log: Записывает строку в лог с временной меткой ---
# Аргумент: $1 = сообщение
write_log() {
    local msg="$1"
    printf "%s | %s\n" "$(date '+%H:%M:%S')" "$msg" >> "$LOG_FILE"
}

# --- do_ping: Кроссплатформенная обёртка для ping ---
# Решает все различия между Linux и macOS:
#   1) macOS: -W в миллисекундах, Linux: -W в секундах
#   2) Linux: -4 для принудительного IPv4, macOS: ping уже только IPv4
#   3) Добавляет -v на macOS для подробного вывода (per-packet строки)
# Аргументы: все аргументы ping КРОМЕ -W (таймаут задаётся через $PING_TIMEOUT_SEC)
# Использование: do_ping [-c COUNT] [-s SIZE] [другие_флаги] ХОСТ
# Переменная PING_TIMEOUT_SEC (по умолчанию 1) задаёт таймаут в СЕКУНДАХ
do_ping() {
    local timeout_sec="${PING_TIMEOUT_SEC:-1}"
    # Проверяем, передан ли флаг -q (quiet) — если да, не добавляем -v на macOS
    # (иначе -v перебивает -q и ломает парсинг summary-статистики)
    local has_quiet=0
    local arg
    for arg in "$@"; do
        [ "$arg" = "-q" ] && has_quiet=1
    done
    if [ "$OS_TYPE" = "Darwin" ]; then
        # macOS: -W принимает миллисекунды, добавляем -v для подробного вывода (если нет -q)
        local timeout_ms=$((timeout_sec * 1000))
        if [ "$has_quiet" -eq 1 ]; then
            ping -W "$timeout_ms" "$@" 2>&1
        else
            ping -v -W "$timeout_ms" "$@" 2>&1
        fi
    else
        # Linux: -W принимает секунды, -4 принудительно IPv4
        ping -4 -W "$timeout_sec" "$@" 2>&1
    fi
}

# --- do_ping_df: Ping с запретом фрагментации (для теста MTU) ---
# macOS: -D, Linux: -M do
do_ping_df() {
    local timeout_sec="${PING_TIMEOUT_SEC:-1}"
    if [ "$OS_TYPE" = "Darwin" ]; then
        local timeout_ms=$((timeout_sec * 1000))
        ping -v -D -W "$timeout_ms" "$@" 2>&1
    else
        ping -4 -M do -W "$timeout_sec" "$@" 2>&1
    fi
}

# --- test_port_quick: Проверяет доступность TCP-порта без sudo ---
# Аргументы: $1 = IP/хост, $2 = порт, $3 = таймаут в секундах (по умолчанию 1)
# Возвращает: 0 (успех) или 1 (неудача)
test_port_quick() {
    local host="$1" port="$2" timeout="${3:-1}"
    # Способ 1: /dev/tcp — встроенная фича bash (самый портативный)
    # Запускаем в подоболочке с таймаутом через timeout или фоновый процесс
    if command -v timeout &>/dev/null; then
        # Linux: есть утилита timeout из coreutils
        timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
        return $?
    else
        # macOS: нет timeout, используем фоновый процесс с kill
        ( bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null ) &
        local pid=$!
        # Ждём завершения в пределах таймаута
        local i=0
        while [ $i -lt "$((timeout * 10))" ]; do
            # Проверяем жив ли процесс
            if ! kill -0 "$pid" 2>/dev/null; then
                # Процесс завершился — проверяем код возврата
                wait "$pid" 2>/dev/null
                return $?
            fi
            sleep 0.1
            i=$((i + 1))
        done
        # Таймаут — убиваем процесс
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        return 1
    fi
}

# --- measure_dns: Измеряет время DNS-запроса в миллисекундах ---
# Аргументы: $1 = DNS-сервер (пусто = системный), $2 = имя хоста
# Выводит: время в миллисекундах
measure_dns() {
    local server="$1" hostname="$2"
    local start_ns end_ns elapsed_ms

    # Засекаем время. date +%s%N даёт наносекунды на Linux.
    # На macOS %N не поддерживается, поэтому используем python/perl как фоллбэк.
    if date +%s%N &>/dev/null && [ "$(date +%s%N)" != "%N" ] 2>/dev/null; then
        start_ns="$(date +%s%N)"
    else
        # macOS fallback: perl даёт микросекунды
        start_ns="$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1e9' 2>/dev/null || echo 0)"
    fi

    # Выполняем DNS-запрос
    if [ -n "$server" ]; then
        # Если указан конкретный DNS-сервер — используем dig или host
        if command -v dig &>/dev/null; then
            dig +short +time=2 +tries=1 "@${server}" "$hostname" A &>/dev/null
        elif command -v host &>/dev/null; then
            host -W 2 "$hostname" "$server" &>/dev/null
        else
            # Фоллбэк: ping один раз (сработает только для системного DNS)
            PING_TIMEOUT_SEC=2 do_ping -c 1 "$hostname" &>/dev/null
        fi
    else
        # Системный DNS — просто резолвим имя
        if command -v dig &>/dev/null; then
            dig +short +time=2 +tries=1 "$hostname" A &>/dev/null
        elif command -v host &>/dev/null; then
            host -W 2 "$hostname" &>/dev/null
        else
            PING_TIMEOUT_SEC=2 do_ping -c 1 "$hostname" &>/dev/null
        fi
    fi

    # Замеряем финальное время
    if date +%s%N &>/dev/null && [ "$(date +%s%N)" != "%N" ] 2>/dev/null; then
        end_ns="$(date +%s%N)"
    else
        end_ns="$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1e9' 2>/dev/null || echo 0)"
    fi

    # Считаем разницу в миллисекундах
    if [ "$start_ns" -gt 0 ] 2>/dev/null && [ "$end_ns" -gt 0 ] 2>/dev/null; then
        elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
        echo "$elapsed_ms"
    else
        echo "N/A"
    fi
}

# --- cmd_exists: Проверяет наличие команды в системе ---
# Аргумент: $1 = имя команды
cmd_exists() {
    command -v "$1" &>/dev/null
}

# --- safe_read: Безопасное чтение пользовательского ввода ---
# Работает даже если stdin перенаправлен
safe_read() {
    local prompt="$1" varname="$2"
    # Пытаемся читать из /dev/tty (реальный терминал), если доступен
    if [ -t 0 ]; then
        printf "%s" "$prompt"
        IFS= read -r "$varname"
    elif [ -e /dev/tty ]; then
        printf "%s" "$prompt" > /dev/tty
        IFS= read -r "$varname" < /dev/tty
    else
        printf "%s" "$prompt"
        IFS= read -r "$varname"
    fi
}

# ==============================================================================
# --- ИНТЕРФЕЙС И ВВОД ДАННЫХ ---
# ==============================================================================

# Очистка экрана
clear 2>/dev/null || printf "\033c"

# Баннер (ASCII-арт логотипа A1)
printf "${COLOR_RED}"
cat << 'BANNER'
    █████╗  ██╗
   ██╔══██╗███║
   ███████║╚██║
   ██╔══██║ ██║
   ██║  ██║ ╚═╝
   ╚═╝  ╚═╝
   СЕТЕВАЯ ДИАГНОСТИКА
BANNER
printf "${COLOR_RESET}"
echo "--------------------------------------------------"

# --- Ввод номера лицевого счёта ---
ACC_NUM=""
while true; do
    printf "\n ${COLOR_CYAN}[?] Введите номер вашего лицевого счета:${COLOR_RESET}\n"
    safe_read "  > " ACC_NUM
    # Убираем пробелы по краям
    ACC_NUM="$(echo "$ACC_NUM" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Проверка: не пустой
    if [ -z "$ACC_NUM" ]; then
        printf " ${COLOR_RED}[!] Номер счета обязателен.${COLOR_RESET}\n"
        continue
    fi
    # Проверка: только латиница, цифры и подчёркивание
    if ! echo "$ACC_NUM" | grep -qE '^[a-zA-Z0-9_]+$'; then
        printf " ${COLOR_RED}[!] Ошибка: используйте только латинские буквы, цифры и '_'.${COLOR_RESET}\n"
        continue
    fi
    break
done

# --- Ввод целевого сайта (необязательно) ---
TARGET_SITE=""
printf "\n ${COLOR_CYAN}[?] Введите адрес сайта или нажмите ENTER для общей диагностики:${COLOR_RESET}\n"
safe_read "  > " RAW_INPUT

# Извлекаем доменное имя из произвольного ввода (URL, текст и т.п.)
if [ -n "$RAW_INPUT" ]; then
    # Приводим к нижнему регистру, извлекаем домен регуляркой через grep/sed
    CLEAN_INPUT="$(echo "$RAW_INPUT" | tr '[:upper:]' '[:lower:]')"
    # Удаляем протокол если есть
    CLEAN_INPUT="$(echo "$CLEAN_INPUT" | sed 's|^https\?://||')"
    # Берём всё до первого / или пробела
    CLEAN_INPUT="$(echo "$CLEAN_INPUT" | sed 's|[/ ].*||')"
    # Удаляем www.
    CLEAN_INPUT="$(echo "$CLEAN_INPUT" | sed 's|^www\.||')"
    # Удаляем завершающую точку
    CLEAN_INPUT="$(echo "$CLEAN_INPUT" | sed 's|\.$||')"
    # Простая валидация: домен должен содержать хотя бы одну точку
    if echo "$CLEAN_INPUT" | grep -qE '^[a-z0-9][a-z0-9.-]+\.[a-z]{2,}$'; then
        TARGET_SITE="$CLEAN_INPUT"
    fi
fi

# --- Формируем списки целей в зависимости от ввода ---
if [ -n "$TARGET_SITE" ]; then
    DIAG_LABEL="$TARGET_SITE"
    TARGETS="$TARGET_SITE 8.8.8.8 1.1.1.1"
    MTR_DEST="$TARGET_SITE"
    SSL_TEST_HOST="$TARGET_SITE"
else
    DIAG_LABEL="Общая диагностика"
    TARGETS="google.com ya.ru onliner.by 8.8.8.8 1.1.1.1"
    MTR_DEST="8.8.8.8"
    SSL_TEST_HOST="a1.by"
fi

# ==============================================================================
# --- ПОИСК РЕЗЕРВНОГО УЗЛА (DNS/ICMP FALLBACK) ---
# ==============================================================================
# Пробуем найти первый отвечающий публичный DNS
RELIABLE_HOSTS="8.8.8.8 1.1.1.1 77.88.8.8 9.9.9.9"
MAIN_DNS=""
printf " ${COLOR_CYAN}[?] Поиск оптимального эталонного узла... ${COLOR_RESET}"

for h in $RELIABLE_HOSTS; do
    # Проверяем доступность порта 53 (DNS) через TCP
    if test_port_quick "$h" 53 1; then
        MAIN_DNS="$h"
        break
    fi
done
# Если ничего не найдено — берём 8.8.8.8 по умолчанию
if [ -z "$MAIN_DNS" ]; then
    MAIN_DNS="8.8.8.8"
fi
printf "${COLOR_GREEN}%s${COLOR_RESET}\n" "$MAIN_DNS"

# --- Удаляем старые файлы диагностики ---
# find с -maxdepth 1 чтобы не лезть в подпапки
find "$DIAG_DIR" -maxdepth 1 -name "A1*.txt" -type f -delete 2>/dev/null
find "$DIAG_DIR" -maxdepth 1 -name "A1*.sha256" -type f -delete 2>/dev/null

# --- Инициализируем лог-файл ---
{
    echo "ОТЧЕТ ДИАГНОСТИКИ СЕТИ"
    echo "Лицевой счет: $ACC_NUM"
    echo "Режим: $DIAG_LABEL"
    echo "Запуск: $(date)"
    echo "ОС: $OS_TYPE ($(uname -r))"
} > "$LOG_FILE"

printf " ${COLOR_YELLOW}Анализ запущен. Пожалуйста, подождите (около 5-6 минут)...${COLOR_RESET}\n\n"

# ==============================================================================
# --- 1. СИСТЕМА ---
# ==============================================================================
write_step "1/12" "Состояние системы"
write_log_header "ИНФОРМАЦИЯ О СИСТЕМЕ"

# --- Имя хоста и ядро ---
write_log "Хост: $(hostname 2>/dev/null || echo 'N/A')"
write_log "Ядро: $(uname -srm)"
# --- Uptime (время работы с последней перезагрузки) ---
write_log "Uptime: $(uptime 2>/dev/null || echo 'N/A')"

# --- Определение виртуализации (VPS/контейнер/bare metal) ---
# Полезно для диагностики: сетевые проблемы на VPS имеют другую природу
VIRT_TYPE="Bare Metal (физический сервер)"
if [ "$OS_TYPE" = "Linux" ]; then
    # Проверяем systemd-detect-virt (самый надёжный способ)
    if cmd_exists systemd-detect-virt; then
        VIRT_RESULT="$(systemd-detect-virt 2>/dev/null)"
        if [ "$VIRT_RESULT" != "none" ] && [ -n "$VIRT_RESULT" ]; then
            VIRT_TYPE="$VIRT_RESULT"
        fi
    # Фоллбэк: проверяем /proc/1/cgroup на признаки контейнера
    elif grep -qE 'docker|lxc|kubepods|containerd' /proc/1/cgroup 2>/dev/null; then
        VIRT_TYPE="Container (Docker/LXC)"
    # Фоллбэк: DMI через /sys
    elif [ -f /sys/class/dmi/id/product_name ]; then
        DMI_PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
        case "$DMI_PRODUCT" in
            *VirtualBox*)   VIRT_TYPE="VirtualBox" ;;
            *VMware*)       VIRT_TYPE="VMware" ;;
            *KVM*|*QEMU*)   VIRT_TYPE="KVM/QEMU" ;;
            *Hyper-V*)      VIRT_TYPE="Hyper-V" ;;
            *Xen*)          VIRT_TYPE="Xen" ;;
            *)              ;;
        esac
    # Фоллбэк: hypervisor в /proc/cpuinfo
    elif grep -qi 'hypervisor' /proc/cpuinfo 2>/dev/null; then
        VIRT_TYPE="Виртуальная машина (тип не определён)"
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: проверяем через sysctl (Apple Silicon VM или Parallels/VMware)
    HW_MODEL="$(sysctl -n hw.model 2>/dev/null)"
    if echo "$HW_MODEL" | grep -qi "virtual\|vmware\|parallels"; then
        VIRT_TYPE="$HW_MODEL"
    fi
fi
write_log "Виртуализация: $VIRT_TYPE"

# --- Информация о процессоре ---
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: sysctl содержит информацию о CPU
    CPU_NAME="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'N/A')"
    CPU_CORES="$(sysctl -n hw.ncpu 2>/dev/null || echo '?')"
    # Средняя загрузка (load average за 1/5/15 мин)
    LOAD_AVG="$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' || uptime | sed 's/.*load average[s]*: //')"
else
    # Linux: /proc/cpuinfo
    CPU_NAME="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || echo 'N/A')"
    CPU_CORES="$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')"
    LOAD_AVG="$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || uptime | sed 's/.*load average[s]*: //')"
fi
write_log "ЦП: $CPU_NAME | Ядер: $CPU_CORES | Load avg: $LOAD_AVG"

# --- Информация об оперативной памяти ---
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: общий объём через sysctl, свободная — через vm_stat
    TOTAL_MEM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
    TOTAL_MEM_GB="$(awk "BEGIN {printf \"%.2f\", $TOTAL_MEM_BYTES / 1073741824}")"
    # vm_stat выдаёт страницы по 4096 байт (обычно), считаем свободные + inactive
    PAGE_SIZE="$(vm_stat 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo 4096)"
    FREE_PAGES="$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')"
    INACTIVE_PAGES="$(vm_stat 2>/dev/null | awk '/Pages inactive/ {gsub(/\./,"",$3); print $3}')"
    FREE_PAGES="${FREE_PAGES:-0}"
    INACTIVE_PAGES="${INACTIVE_PAGES:-0}"
    FREE_MEM_GB="$(awk "BEGIN {printf \"%.2f\", ($FREE_PAGES + $INACTIVE_PAGES) * $PAGE_SIZE / 1073741824}")"
    write_log "ОЗУ: Свободно ~${FREE_MEM_GB} ГБ из ${TOTAL_MEM_GB} ГБ (free+inactive)"
else
    # Linux: /proc/meminfo (значения в kB)
    MEM_TOTAL="$(awk '/^MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    MEM_AVAIL="$(awk '/^MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    TOTAL_MEM_GB="$(awk "BEGIN {printf \"%.2f\", $MEM_TOTAL / 1048576}")"
    FREE_MEM_GB="$(awk "BEGIN {printf \"%.2f\", $MEM_AVAIL / 1048576}")"
    write_log "ОЗУ: Доступно ${FREE_MEM_GB} ГБ из ${TOTAL_MEM_GB} ГБ"
fi

# --- Дисковая подсистема ---
write_log_header "ДИСКОВАЯ ПОДСИСТЕМА"
# df -h показывает диски в человекочитаемом формате
# Исключаем виртуальные ФС (tmpfs, devtmpfs и т.д.)
if [ "$OS_TYPE" = "Darwin" ]; then
    df -h 2>/dev/null | grep -E '^/dev/' >> "$LOG_FILE"
else
    df -h 2>/dev/null | grep -vE '^(tmpfs|devtmpfs|overlay|shm|Filesystem)' >> "$LOG_FILE"
fi

# Проверяем свободное место на корневом разделе
ROOT_FREE_KB="$(df -k / 2>/dev/null | awk 'NR==2 {print $4}')"
ROOT_TOTAL_KB="$(df -k / 2>/dev/null | awk 'NR==2 {print $2}')"
if [ -n "$ROOT_FREE_KB" ] && [ "$ROOT_FREE_KB" -gt 0 ] 2>/dev/null; then
    ROOT_FREE_GB="$(awk "BEGIN {printf \"%.2f\", $ROOT_FREE_KB / 1048576}")"
    ROOT_TOTAL_GB="$(awk "BEGIN {printf \"%.2f\", $ROOT_TOTAL_KB / 1048576}")"
    ROOT_FREE_PCT="$(awk "BEGIN {printf \"%.1f\", $ROOT_FREE_KB * 100 / $ROOT_TOTAL_KB}")"
    write_log "Раздел /: Свободно ${ROOT_FREE_GB} ГБ из ${ROOT_TOTAL_GB} ГБ (${ROOT_FREE_PCT}%)"

    # Предупреждение если места мало
    ROOT_FREE_GB_INT="${ROOT_FREE_GB%%.*}"
    ROOT_FREE_PCT_INT="${ROOT_FREE_PCT%%.*}"
    if [ "${ROOT_FREE_GB_INT:-0}" -lt 5 ] 2>/dev/null || [ "${ROOT_FREE_PCT_INT:-100}" -lt 10 ] 2>/dev/null; then
        # Проверяем: возможно это immutable дистрибутив (SteamOS, Fedora Silverblue и т.д.)
        # У них корневой раздел маленький по дизайну и read-only — это нормально
        IS_IMMUTABLE=0
        if [ -f /etc/os-release ]; then
            # SteamOS: VARIANT_ID=steamdeck или ID=steamos
            if grep -qiE 'steamos|steamdeck' /etc/os-release 2>/dev/null; then
                IS_IMMUTABLE=1
            fi
            # Fedora Silverblue/Kinoite: VARIANT_ID=silverblue|kinoite
            if grep -qiE 'silverblue|kinoite' /etc/os-release 2>/dev/null; then
                IS_IMMUTABLE=1
            fi
        fi
        # Также проверяем read-only корень
        if mount 2>/dev/null | grep ' / ' | grep -q 'ro[,)]'; then
            IS_IMMUTABLE=1
        fi
        if [ "$IS_IMMUTABLE" -eq 1 ]; then
            write_log "  Раздел / небольшой — это нормально для immutable-дистрибутива (SteamOS/Silverblue и т.д.)."
        else
            write_log "  ! ВНИМАНИЕ: Критически мало места на корневом разделе."
        fi
    fi
fi
write_status_ok

# ==============================================================================
# --- 2. СЕТЕВЫЕ ИНТЕРФЕЙСЫ И ТЕСТ MTU ---
# ==============================================================================
write_step "2/12" "Сетевые адаптеры и MTU"
write_log_header "СЕТЕВЫЕ ИНТЕРФЕЙСЫ"

# Список активных интерфейсов с IP-адресами
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: ifconfig — единственный надёжный вариант без sudo
    ifconfig 2>/dev/null | grep -E '(^[a-z]|inet |status|media)' >> "$LOG_FILE"
else
    # Linux: ip addr — современная замена ifconfig
    if cmd_exists ip; then
        ip -br addr 2>/dev/null >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        ip addr show 2>/dev/null >> "$LOG_FILE"
    elif cmd_exists ifconfig; then
        ifconfig 2>/dev/null >> "$LOG_FILE"
    fi
fi

# --- Тест MTU: ищем максимальный размер пакета без фрагментации ---
write_log_header "ПОИСК ОПТИМАЛЬНОГО MTU"
MTU_FOUND=0

# Перебираем размеры от 1472 до 1300 с шагом 10 (грубый поиск)
# Используем do_ping_df — обёртку с запретом фрагментации (macOS: -D, Linux: -M do)
PING_TIMEOUT_SEC=1
for size in $(seq 1472 -10 1300); do
    # ping с запретом фрагментации: -s размер_данных, -c 1 пакет
    MTU_RESULT="$(do_ping_df -c 1 -s "$size" "$MAIN_DNS")"
    # Проверяем что НЕТ ошибки фрагментации
    if ! echo "$MTU_RESULT" | grep -qiE "frag|too long|message too long|would exceed|mtu"; then
        # Нашли приблизительный размер — точный поиск с шагом 1
        for exact_size in $(seq $((size + 9)) -1 "$size"); do
            EXACT_RESULT="$(do_ping_df -c 1 -s "$exact_size" "$MAIN_DNS")"
            if ! echo "$EXACT_RESULT" | grep -qiE "frag|too long|message too long|would exceed|mtu"; then
                # Оптимальный MTU = размер данных + 28 байт (IP 20 + ICMP 8)
                OPTIMAL_MTU=$((exact_size + 28))
                write_log "Оптимальный MTU: $OPTIMAL_MTU (размер данных ICMP: $exact_size байт)"
                MTU_FOUND=1
                break
            fi
        done
        break
    fi
done

if [ "$MTU_FOUND" -eq 0 ]; then
    write_log "  ! Не удалось определить оптимальный MTU. Возможна блокировка ICMP провайдером."
fi
write_status_ok

# ==============================================================================
# --- 3. БРАНДМАУЭР, ПРОКСИ И ВРЕМЯ ---
# ==============================================================================
write_step "3/12" "Защита и время"
write_log_header "БРАНДМАУЭР И ПРОКСИ"

# --- Проверяем файрвол ---
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: pfctl требует sudo — пропускаем (скрипт работает без повышения прав)
    # Application Firewall (через defaults — не требует sudo)
    ALF_STATUS="$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo 'N/A')"
    case "$ALF_STATUS" in
        0) write_log "Application Firewall: Выключен" ;;
        1) write_log "Application Firewall: Включен (стандартный режим)" ;;
        2) write_log "Application Firewall: Включен (блокировать все входящие)" ;;
        *) write_log "Application Firewall: Не удалось определить (статус: $ALF_STATUS)" ;;
    esac
else
    # Linux: пробуем iptables без sudo — молча пропускаем при отказе в правах
    FIREWALL_FOUND=0
    if cmd_exists iptables; then
        IPT_RESULT="$(iptables -L -n 2>&1)"
        if ! echo "$IPT_RESULT" | grep -q "Permission denied\|Operation not permitted"; then
            write_log "iptables:"
            echo "$IPT_RESULT" | head -20 >> "$LOG_FILE"
            FIREWALL_FOUND=1
        fi
    fi
    # nftables — новый файрвол (только если доступен без sudo)
    if cmd_exists nft; then
        NFT_RESULT="$(nft list ruleset 2>&1)"
        if ! echo "$NFT_RESULT" | grep -q "Permission denied\|Operation not permitted"; then
            write_log "nftables:"
            echo "$NFT_RESULT" | head -20 >> "$LOG_FILE"
            FIREWALL_FOUND=1
        fi
    fi
    # ufw — простой фронтенд к iptables (Ubuntu/Debian)
    if cmd_exists ufw; then
        UFW_RESULT="$(ufw status 2>&1)"
        if ! echo "$UFW_RESULT" | grep -q "Permission denied\|Operation not permitted"; then
            write_log "UFW: $UFW_RESULT"
            FIREWALL_FOUND=1
        fi
    fi
    # Если ни одна утилита не доступна без sudo — молча пишем в лог
    if [ "$FIREWALL_FOUND" -eq 0 ]; then
        write_log "Файрвол: Проверка недоступна без прав root (iptables/nftables/ufw требуют sudo)."
    fi
fi

# --- Проверяем системный прокси ---
# Через переменные окружения
if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$https_proxy" ] || [ -n "$HTTPS_PROXY" ]; then
    write_log "Прокси (env): http=${http_proxy:-${HTTP_PROXY:-нет}} | https=${https_proxy:-${HTTPS_PROXY:-нет}}"
else
    write_log "Системный прокси (env): Не обнаружен"
fi

# macOS: системные настройки прокси через scutil/networksetup
if [ "$OS_TYPE" = "Darwin" ]; then
    # Получаем активный сетевой сервис
    ACTIVE_SERVICE="$(networksetup -listallnetworkservices 2>/dev/null | grep -v '^\*' | head -3)"
    for svc in $ACTIVE_SERVICE; do
        HTTP_PROXY_INFO="$(networksetup -getwebproxy "$svc" 2>/dev/null)"
        if echo "$HTTP_PROXY_INFO" | grep -q "Enabled: Yes"; then
            write_log "macOS прокси ($svc): $HTTP_PROXY_INFO"
        fi
    done
fi

# --- Проверяем VPN-интерфейсы ---
write_log "--- Проверка VPN ---"
VPN_DETECTED=""
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: ищем utun/ipsec/ppp интерфейсы (типичные для VPN)
    # ВАЖНО: macOS создаёт системные utun-интерфейсы (IPSEC IKE, iCloud Private Relay и т.д.)
    # У них есть ТОЛЬКО link-local IPv6 (fe80::) — это НЕ VPN.
    # Настоящий VPN-туннель будет иметь IPv4-адрес (inet) или глобальный IPv6 (не fe80::).
    # Фильтруем: оставляем только те utun, у которых есть inet или глобальный inet6
    VPN_IFS=""
    for vpn_iface in $(ifconfig 2>/dev/null | grep -E '^(utun|ipsec|ppp)[0-9]' | awk -F: '{print $1}'); do
        # Получаем блок ifconfig для этого интерфейса
        IFACE_BLOCK="$(ifconfig "$vpn_iface" 2>/dev/null)"
        # Проверяем: есть ли IPv4-адрес (inet, не inet6)
        HAS_IPV4="$(echo "$IFACE_BLOCK" | grep -c 'inet [0-9]')"
        # Проверяем: есть ли глобальный IPv6 (не link-local fe80::)
        HAS_GLOBAL_V6="$(echo "$IFACE_BLOCK" | grep 'inet6' | grep -cv 'fe80::')"
        if [ "$HAS_IPV4" -gt 0 ] || [ "$HAS_GLOBAL_V6" -gt 0 ]; then
            # Это реальный VPN-туннель — у него есть маршрутизируемый адрес
            VPN_IFS="${VPN_IFS:+$VPN_IFS,}$vpn_iface"
        fi
    done
    if [ -n "$VPN_IFS" ]; then
        VPN_DETECTED="$VPN_IFS"
    fi
    # Также проверяем через scutil
    SCUTIL_VPN="$(scutil --nc list 2>/dev/null | grep -i 'connected' || true)"
    if [ -n "$SCUTIL_VPN" ]; then
        VPN_DETECTED="${VPN_DETECTED:+$VPN_DETECTED, }scutil: $SCUTIL_VPN"
    fi
else
    # Linux: ищем tun/tap/wg интерфейсы
    if cmd_exists ip; then
        VPN_IFS="$(ip link show 2>/dev/null | grep -oE '(tun|tap|wg|ppp|ipsec)[0-9]+' || true)"
    else
        VPN_IFS="$(ifconfig 2>/dev/null | grep -oE '(tun|tap|wg|ppp|ipsec)[0-9]+' || true)"
    fi
    if [ -n "$VPN_IFS" ]; then
        VPN_DETECTED="$VPN_IFS"
    fi
    # Проверяем WireGuard
    if [ -d /etc/wireguard ] && ls /etc/wireguard/*.conf &>/dev/null; then
        VPN_DETECTED="${VPN_DETECTED:+$VPN_DETECTED, }WireGuard конфиг найден"
    fi
fi

if [ -n "$VPN_DETECTED" ]; then
    write_log "Активный VPN: $VPN_DETECTED"
else
    write_log "Активный VPN: Не обнаружен"
fi

# --- Синхронизация времени ---
write_log_header "СИНХРОНИЗАЦИЯ ВРЕМЕНИ"
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: sntp (без sudo) для проверки NTP
    # ВАЖНО: sntp возвращает ненулевой код если смещение != 0 (т.е. почти всегда).
    # Код возврата НЕ означает ошибку. Проверяем наличие вывода, а не exit code.
    # Также собираем stderr — sntp может писать результат туда
    if cmd_exists sntp; then
        SNTP_RESULT="$(sntp -S time.apple.com 2>&1)"
        if [ -n "$SNTP_RESULT" ]; then
            # Проверяем: получили ли мы данные о смещении (offset), или реальную ошибку (timeout/no route)
            if echo "$SNTP_RESULT" | grep -qiE 'offset|delay|time\.apple'; then
                write_log "NTP (sntp): $SNTP_RESULT"
            elif echo "$SNTP_RESULT" | grep -qiE 'timeout|timed out|no route|unreachable|refused'; then
                write_log "NTP: Сервер time.apple.com недоступен ($SNTP_RESULT)"
            else
                # Неизвестный формат — показываем как есть
                write_log "NTP (sntp): $SNTP_RESULT"
            fi
        else
            write_log "NTP: sntp не вернул данных (сервер time.apple.com недоступен?)"
        fi
    else
        write_log "NTP: утилита sntp не найдена"
    fi
else
    # Linux: timedatectl показывает статус синхронизации
    if cmd_exists timedatectl; then
        timedatectl status 2>/dev/null >> "$LOG_FILE"
    elif cmd_exists ntpq; then
        ntpq -p 2>/dev/null >> "$LOG_FILE"
    elif cmd_exists chronyc; then
        chronyc tracking 2>/dev/null >> "$LOG_FILE"
    else
        write_log "Утилиты NTP (timedatectl/ntpq/chronyc) не найдены."
    fi
fi
write_log "Текущее время: $(date)"

# --- Файл hosts ---
write_log_header "ФАЙЛ HOSTS"
HOSTS_FILE="/etc/hosts"
if [ -f "$HOSTS_FILE" ]; then
    # Фильтруем: убираем комментарии, пустые строки, localhost, и стандартные записи
    # ip6-localnet, ip6-mcastprefix, ip6-allrouters, ip6-allnodes, ip6-loopback — стандартные
    # Также фильтруем имя хоста машины (часто добавляется автоматически в /etc/hosts)
    MY_HOSTNAME="$(hostname 2>/dev/null || true)"
    HOSTS_CUSTOM="$(grep -vE "^\s*#|^\s*$|localhost|broadcasthost|::1|ip6-|fe00::|ff00::|ff02::" "$HOSTS_FILE" 2>/dev/null || true)"
    # Дополнительно убираем строку с именем хоста (127.0.1.1 hostname или 127.0.0.1 hostname)
    if [ -n "$MY_HOSTNAME" ]; then
        HOSTS_CUSTOM="$(echo "$HOSTS_CUSTOM" | grep -v "$MY_HOSTNAME" || true)"
    fi
    # Убираем пустые строки после фильтрации
    HOSTS_CUSTOM="$(echo "$HOSTS_CUSTOM" | sed '/^\s*$/d')"

    if [ -n "$HOSTS_CUSTOM" ]; then
        write_log "ВНИМАНИЕ: Обнаружены потенциально влияющие записи в файле hosts:"
        echo "$HOSTS_CUSTOM" | while IFS= read -r line; do
            write_log "  > $line"
        done
    else
        write_log "Файл hosts не содержит сторонних правок (только стандартные записи)."
    fi
else
    write_log "Файл hosts не найден по стандартному пути."
fi
write_status_ok

# --- Функция: определяем hardware-тип интерфейса на macOS ---
# Использует networksetup -listallhardwareports для маппинга interface → Hardware Port
# Аргумент: $1 = имя интерфейса (en0, en1 и т.д.)
# Выводит: тип ("Wi-Fi", "Ethernet", "Thunderbolt Ethernet", "USB Ethernet" и т.д.)
_macos_get_hw_type() {
    local iface="$1"
    # networksetup -listallhardwareports выдаёт блоки:
    #   Hardware Port: Wi-Fi
    #   Device: en0
    #   ...
    # Ищем блок где Device: совпадает с нашим интерфейсом
    local hw_port
    hw_port="$(networksetup -listallhardwareports 2>/dev/null | awk -v dev="$iface" '
        /^Hardware Port:/ { port = substr($0, index($0, ":")+2) }
        /^Device:/ && $2 == dev { print port; exit }
    ')"
    echo "${hw_port:-Unknown}"
}

# --- Функция определения подключения на macOS ---
# Вызывается когда Wi-Fi не обнаружен через airport/system_profiler
# Определяет реальный тип через networksetup (может быть Wi-Fi без airport!)
_macos_detect_connection() {
    local active_if
    active_if="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"

    if [ -n "$active_if" ]; then
        local media_info status_info inet_info hw_type
        media_info="$(ifconfig "$active_if" 2>/dev/null | grep 'media:' | sed 's/^[[:space:]]*//')"
        status_info="$(ifconfig "$active_if" 2>/dev/null | grep 'status:' | awk '{print $2}')"
        inet_info="$(ifconfig "$active_if" 2>/dev/null | grep 'inet ' | awk '{print $2}')"
        hw_type="$(_macos_get_hw_type "$active_if")"

        # Проверяем: это Wi-Fi?
        if echo "$hw_type" | grep -qi 'wi-fi\|wifi\|airport'; then
            # Это Wi-Fi интерфейс! airport не смог его детектировать, но networksetup знает
            IS_WIFI=1
            write_log "Тип подключения: Wi-Fi ($active_if)"
            write_log "  Интерфейс: $active_if | IP: ${inet_info:-нет} | Статус: ${status_info:-?}"
            write_log "  (Детальная статистика Wi-Fi недоступна: утилита airport не найдена)"
            # Пробуем получить RSSI через wdutil (macOS 14.4+, без sudo выдаёт ограниченно)
            if cmd_exists wdutil; then
                local wdutil_info
                wdutil_info="$(wdutil info 2>/dev/null | grep -iE 'RSSI|SSID|Channel|Tx Rate|MCS' | head -10)"
                if [ -n "$wdutil_info" ]; then
                    write_log "  Wi-Fi детали (wdutil):"
                    echo "$wdutil_info" | while IFS= read -r line; do
                        write_log "    $line"
                    done
                fi
            fi
        else
            # Проводное подключение (Ethernet/Thunderbolt/USB)
            local link_speed=""

            # Скорость из media
            if echo "$media_info" | grep -qi '1000baseT\|gigabit'; then
                link_speed="1 Gbps"
            elif echo "$media_info" | grep -qi '100baseT'; then
                link_speed="100 Mbps"
            elif echo "$media_info" | grep -qi '10baseT'; then
                link_speed="10 Mbps"
            fi

            # Если нет скорости — пробуем system_profiler SPEthernetDataType
            if [ -z "$link_speed" ]; then
                local sp_speed
                sp_speed="$(system_profiler SPEthernetDataType 2>/dev/null | grep -i 'Speed:' | head -1 | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')"
                if [ -n "$sp_speed" ]; then
                    link_speed="$sp_speed"
                fi
            fi

            write_log "Тип подключения: ${hw_type} (${active_if})"
            write_log "  Интерфейс: $active_if | IP: ${inet_info:-нет} | Статус: ${status_info:-?}"
            if [ -n "$link_speed" ]; then
                write_log "  Скорость линка: $link_speed"
            fi
            write_log "  Media: ${media_info:-N/A}"
        fi
        ifconfig "$active_if" 2>/dev/null >> "$LOG_FILE"
    else
        write_log "Тип подключения: Не удалось определить (нет default route)"
        ifconfig 2>/dev/null | grep -E '(^en|inet |media:|status:)' >> "$LOG_FILE"
    fi
}

# ==============================================================================
# --- 4. WI-FI И ETHERNET ---
# ==============================================================================
write_step "4/12" "Параметры подключения и сигнал"
write_log_header "АНАЛИЗ ФИЗИЧЕСКОГО УРОВНЯ"

IS_WIFI=0
WIFI_AVG_SIGNAL=0
WIFI_MIN_SIGNAL=0
WIFI_MAX_SIGNAL=0

if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: airport — скрытая утилита Apple для Wi-Fi
    # На macOS 14+ (Sonoma) airport может быть недоступен, используем networksetup как фоллбэк
    AIRPORT="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    # Проверяем Wi-Fi через networksetup (надёжнее чем airport)
    WIFI_SERVICE="$(networksetup -listallnetworkservices 2>/dev/null | grep -i 'wi-fi\|wifi\|airport' | head -1)"
    WIFI_POWER=""
    if [ -n "$WIFI_SERVICE" ]; then
        WIFI_POWER="$(networksetup -getairportpower en0 2>/dev/null | awk '{print $NF}')"
    fi

    if [ -x "$AIRPORT" ]; then
        WIFI_INFO="$("$AIRPORT" -I 2>/dev/null)"
        if echo "$WIFI_INFO" | grep -q "SSID"; then
            IS_WIFI=1
            write_log "Обнаружено Wi-Fi соединение. Сбор статистики (10 сек)..."
            SIGNALS=""
            # Собираем 10 замеров уровня сигнала с интервалом 1 сек
            for i in $(seq 1 10); do
                # RSSI — уровень сигнала в dBm (чем ближе к 0, тем лучше)
                RSSI="$("$AIRPORT" -I 2>/dev/null | awk '/agrCtlRSSI/ {print $2}')"
                if [ -n "$RSSI" ]; then
                    SIGNALS="$SIGNALS $RSSI"
                fi
                sleep 1
            done

            if [ -n "$SIGNALS" ]; then
                # Вычисляем min/max/avg через awk
                WIFI_STATS="$(echo "$SIGNALS" | tr ' ' '\n' | grep -E '^-?[0-9]+$' | awk '
                    BEGIN {min=999; max=-999; sum=0; n=0}
                    {
                        if ($1 < min) min=$1;
                        if ($1 > max) max=$1;
                        sum+=$1; n++
                    }
                    END {if(n>0) printf "%d %d %.1f %d\n", min, max, sum/n, max-min; else print "0 0 0 0"}
                ')"
                WIFI_MIN_SIGNAL="$(echo "$WIFI_STATS" | awk '{print $1}')"
                WIFI_MAX_SIGNAL="$(echo "$WIFI_STATS" | awk '{print $2}')"
                WIFI_AVG_SIGNAL="$(echo "$WIFI_STATS" | awk '{print $3}')"
                WIFI_VARIATION="$(echo "$WIFI_STATS" | awk '{print $4}')"
                write_log "RSSI: Min: ${WIFI_MIN_SIGNAL}dBm | Max: ${WIFI_MAX_SIGNAL}dBm | Avg: ${WIFI_AVG_SIGNAL}dBm (Вариативность: ${WIFI_VARIATION}dBm)"
            fi
            echo "$WIFI_INFO" >> "$LOG_FILE"

            # --- Tx Rate / канальная скорость Wi-Fi (важно для инженеров) ---
            TX_RATE="$(echo "$WIFI_INFO" | awk '/lastTxRate/ {print $2}')"
            if [ -n "$TX_RATE" ]; then
                write_log "Канальная скорость (Tx Rate): ${TX_RATE} Mbps"
            fi

            # Сканирование окружающих Wi-Fi сетей
            write_log_header "ОКРУЖАЮЩИЕ WI-FI СЕТИ"
            SCAN_RESULT="$("$AIRPORT" -s 2>/dev/null)"
            if [ -n "$SCAN_RESULT" ]; then
                echo "$SCAN_RESULT" >> "$LOG_FILE"
                NET_COUNT="$(echo "$SCAN_RESULT" | tail -n +2 | wc -l | tr -d ' ')"
                write_log "Обнаружено соседних сетей: $NET_COUNT"
                if [ "$NET_COUNT" -gt 15 ] 2>/dev/null; then
                    write_log "  ! Эфир сильно зашумлен (более 15 сетей). Рекомендуется использовать 5GHz."
                fi
            fi
        else
            # Wi-Fi не подключен через airport — определяем тип через system_profiler
            _macos_detect_connection
        fi
    else
        # airport недоступен (macOS 14+ Sonoma) — пробуем через networksetup/system_profiler
        if [ -n "$WIFI_SERVICE" ] && [ "$WIFI_POWER" = "On" ]; then
            # Wi-Fi включен — пробуем получить информацию через system_profiler
            WIFI_DETAILS="$(system_profiler SPAirPortDataType 2>/dev/null | grep -A20 'Current Network Information' | head -25)"
            if [ -n "$WIFI_DETAILS" ]; then
                IS_WIFI=1
                write_log "Обнаружено Wi-Fi соединение (определено через system_profiler)."
                echo "$WIFI_DETAILS" >> "$LOG_FILE"
                # RSSI из system_profiler
                RSSI_VAL="$(echo "$WIFI_DETAILS" | grep -i 'Signal.*Noise' | grep -oE '\-[0-9]+' | head -1)"
                if [ -n "$RSSI_VAL" ]; then
                    WIFI_AVG_SIGNAL="$RSSI_VAL"
                    write_log "RSSI (однократный замер): ${RSSI_VAL} dBm"
                fi
                # Tx Rate из system_profiler (канальная скорость)
                TX_RATE="$(echo "$WIFI_DETAILS" | grep -i 'Transmit Rate' | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')"
                if [ -n "$TX_RATE" ]; then
                    write_log "Канальная скорость (Tx Rate): $TX_RATE"
                fi
            else
                write_log "Wi-Fi включен ($WIFI_SERVICE), но не подключен к сети."
                _macos_detect_connection
            fi
        else
            _macos_detect_connection
        fi
    fi
else
    # Linux: iwconfig / iw / nmcli для Wi-Fi
    WIFI_IFACE=""
    if cmd_exists iwconfig; then
        # iwconfig без аргументов покажет Wi-Fi интерфейсы
        WIFI_CHECK="$(iwconfig 2>&1 | grep -v 'no wireless' | grep -E 'ESSID|Signal')"
        if [ -n "$WIFI_CHECK" ]; then
            IS_WIFI=1
            WIFI_IFACE="$(iwconfig 2>&1 | grep 'ESSID' | head -1 | awk '{print $1}')"
        fi
    elif cmd_exists iw; then
        # iw dev показывает беспроводные интерфейсы
        WIFI_IFACE="$(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | head -1)"
        if [ -n "$WIFI_IFACE" ]; then
            LINK_INFO="$(iw dev "$WIFI_IFACE" link 2>/dev/null)"
            if echo "$LINK_INFO" | grep -q "Connected"; then
                IS_WIFI=1
            fi
        fi
    elif cmd_exists nmcli; then
        WIFI_CHECK="$(nmcli -t -f TYPE,STATE dev 2>/dev/null | grep 'wifi:connected')"
        if [ -n "$WIFI_CHECK" ]; then
            IS_WIFI=1
            WIFI_IFACE="$(nmcli -t -f TYPE,DEVICE dev 2>/dev/null | grep 'wifi:' | cut -d: -f2 | head -1)"
        fi
    fi

    if [ "$IS_WIFI" -eq 1 ]; then
        write_log "Обнаружено Wi-Fi соединение ($WIFI_IFACE). Сбор статистики (10 сек)..."
        SIGNALS=""
        for i in $(seq 1 10); do
            SIG=""
            if cmd_exists iwconfig && [ -n "$WIFI_IFACE" ]; then
                # iwconfig выдаёт Signal level в dBm
                SIG="$(iwconfig "$WIFI_IFACE" 2>/dev/null | grep -oE 'Signal level=?-?[0-9]+' | grep -oE '\-?[0-9]+$')"
            elif cmd_exists iw && [ -n "$WIFI_IFACE" ]; then
                SIG="$(iw dev "$WIFI_IFACE" link 2>/dev/null | grep 'signal:' | awk '{print $2}')"
            fi
            if [ -n "$SIG" ]; then
                SIGNALS="$SIGNALS $SIG"
            fi
            sleep 1
        done

        if [ -n "$SIGNALS" ]; then
            WIFI_STATS="$(echo "$SIGNALS" | tr ' ' '\n' | grep -E '^-?[0-9]+$' | awk '
                BEGIN {min=999; max=-999; sum=0; n=0}
                {
                    if ($1+0 < min) min=$1+0;
                    if ($1+0 > max) max=$1+0;
                    sum+=$1; n++
                }
                END {if(n>0) printf "%d %d %.1f %d\n", min, max, sum/n, max-min; else print "0 0 0 0"}
            ')"
            WIFI_MIN_SIGNAL="$(echo "$WIFI_STATS" | awk '{print $1}')"
            WIFI_MAX_SIGNAL="$(echo "$WIFI_STATS" | awk '{print $2}')"
            WIFI_AVG_SIGNAL="$(echo "$WIFI_STATS" | awk '{print $3}')"
            WIFI_VARIATION="$(echo "$WIFI_STATS" | awk '{print $4}')"
            write_log "RSSI: Min: ${WIFI_MIN_SIGNAL}dBm | Max: ${WIFI_MAX_SIGNAL}dBm | Avg: ${WIFI_AVG_SIGNAL}dBm (Вариативность: ${WIFI_VARIATION}dBm)"
        fi

        # --- Tx Rate / канальная скорость Wi-Fi (важно для инженеров) ---
        TX_RATE=""
        if cmd_exists iw && [ -n "$WIFI_IFACE" ]; then
            TX_RATE="$(iw dev "$WIFI_IFACE" link 2>/dev/null | grep 'tx bitrate' | awk '{$1=$2=""; print $0}' | sed 's/^[[:space:]]*//')"
        elif cmd_exists iwconfig && [ -n "$WIFI_IFACE" ]; then
            TX_RATE="$(iwconfig "$WIFI_IFACE" 2>/dev/null | grep -oE 'Bit Rate[=:][0-9.]+ [A-Za-z/]+' | sed 's/Bit Rate[=:]//')"
        fi
        if [ -n "$TX_RATE" ]; then
            write_log "Канальная скорость (Tx Rate): $TX_RATE"
        fi

        # Детальная информация об интерфейсе
        if cmd_exists iwconfig; then
            iwconfig "$WIFI_IFACE" 2>/dev/null >> "$LOG_FILE"
        fi
        if cmd_exists iw; then
            iw dev "$WIFI_IFACE" link 2>/dev/null >> "$LOG_FILE"
        fi

        # Сканирование окружающих сетей (обычно нужен root, но пробуем)
        write_log_header "ОКРУЖАЮЩИЕ WI-FI СЕТИ"
        if cmd_exists nmcli; then
            # nmcli может показать кэшированные результаты без sudo
            SCAN_RESULT="$(nmcli -f SSID,SIGNAL,BARS,CHAN,SECURITY dev wifi list 2>/dev/null)"
            if [ -n "$SCAN_RESULT" ]; then
                echo "$SCAN_RESULT" >> "$LOG_FILE"
                NET_COUNT="$(echo "$SCAN_RESULT" | tail -n +2 | grep -c '[^ ]')"
                write_log "Обнаружено соседних сетей: $NET_COUNT"
                if [ "$NET_COUNT" -gt 15 ] 2>/dev/null; then
                    write_log "  ! Эфир сильно зашумлен (более 15 сетей). Рекомендуется 5GHz."
                fi
            else
                write_log "Сканирование Wi-Fi недоступно без sudo."
            fi
        elif cmd_exists iw; then
            # iw scan требует root; пытаемся, но не расстраиваемся
            SCAN_RESULT="$(iw dev "$WIFI_IFACE" scan 2>&1)"
            if echo "$SCAN_RESULT" | grep -q "Permission denied\|Operation not permitted"; then
                write_log "Сканирование Wi-Fi недоступно без sudo (iw)."
            else
                echo "$SCAN_RESULT" | grep -E 'SSID|signal|freq' | head -60 >> "$LOG_FILE"
            fi
        fi
    else
        write_log "Тип подключения: Проводное (Ethernet) или Wi-Fi не обнаружен"
        # Показываем активные Ethernet-интерфейсы
        if cmd_exists ip; then
            ip link show 2>/dev/null | grep -E 'state UP|eth|en' >> "$LOG_FILE"
            # Скорость линка (если доступна) — пробуем несколько способов
            for iface in $(ip -o link show up 2>/dev/null | awk -F: '{print $2}' | tr -d ' ' | grep -vE '^lo$|^docker|^veth|^br-'); do
                SPEED=""
                DUPLEX=""
                # Способ 1: /sys/class/net (не требует утилит, но на VPS часто -1)
                SPEED_RAW="$(cat /sys/class/net/"$iface"/speed 2>/dev/null)"
                if [ -n "$SPEED_RAW" ] && [ "$SPEED_RAW" != "-1" ] 2>/dev/null; then
                    SPEED="$SPEED_RAW"
                    DUPLEX="$(cat /sys/class/net/"$iface"/duplex 2>/dev/null || echo 'N/A')"
                fi
                # Способ 2: ethtool (если sysfs не дал результата)
                if [ -z "$SPEED" ] && cmd_exists ethtool; then
                    ETH_OUT="$(ethtool "$iface" 2>/dev/null)"
                    SPEED="$(echo "$ETH_OUT" | grep -i 'Speed:' | awk '{print $2}' | tr -d 'Mb/s')"
                    DUPLEX="$(echo "$ETH_OUT" | grep -i 'Duplex:' | awk '{print $2}')"
                fi
                # Способ 3: ip link (показывает qlen, mtu, но не скорость — хотя бы покажем что есть)
                if [ -n "$SPEED" ] && [ "$SPEED" != "Unknown!" ] && [ "$SPEED" != "" ]; then
                    write_log "Интерфейс $iface: ${SPEED} Mbps / Duplex: ${DUPLEX:-N/A}"
                else
                    # Показываем хотя бы MTU и состояние
                    MTU_VAL="$(cat /sys/class/net/"$iface"/mtu 2>/dev/null || echo 'N/A')"
                    OPER_STATE="$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo 'N/A')"
                    write_log "Интерфейс $iface: Скорость линка недоступна (VPS?) | MTU: ${MTU_VAL} | Состояние: ${OPER_STATE}"
                fi
            done
        elif cmd_exists ifconfig; then
            ifconfig 2>/dev/null | grep -B1 'inet ' | grep -v '127.0.0.1' >> "$LOG_FILE"
        fi
    fi
fi
write_status_ok

# ==============================================================================
# --- 5. АКТИВНЫЕ ПРОГРАММЫ И РАСШИРЕНИЯ ---
# ==============================================================================
write_step "5/12" "Сетевая активность и браузеры"
write_log_header "ТОП ПРОГРАММ ПО СЕТЕВЫМ СОЕДИНЕНИЯМ"

# --- Список активных TCP-соединений ---
if cmd_exists ss; then
    # ss — современная замена netstat (Linux)
    TOTAL_TCP="$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
    write_log "Всего активных TCP-соединений (ESTABLISHED): $TOTAL_TCP"
    # Группируем по PID/процессу (ss -tnp может требовать sudo для PID)
    SS_OUTPUT="$(ss -tnp state established 2>/dev/null)"
    if echo "$SS_OUTPUT" | grep -q 'users:'; then
        # PID доступны — извлекаем имя процесса и PID, потом резолвим имя
        # Формат users:(("name",pid=1234,fd=5))
        # Извлекаем PID, группируем, и для каждого получаем имя процесса
        echo "$SS_OUTPUT" | grep -oE 'pid=[0-9]+' | sed 's/pid=//' | sort | uniq -c | sort -rn | head -10 | while read -r cnt pid; do
            # Пытаемся получить имя процесса из /proc или через ps
            PNAME=""
            if [ -f "/proc/$pid/comm" ]; then
                PNAME="$(cat "/proc/$pid/comm" 2>/dev/null)"
            fi
            if [ -z "$PNAME" ]; then
                PNAME="$(ps -p "$pid" -o comm= 2>/dev/null || echo '')"
            fi
            # Если имя всё ещё пустое — пробуем cmdline
            if [ -z "$PNAME" ] && [ -f "/proc/$pid/cmdline" ]; then
                PNAME="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | awk '{print $1}' | xargs basename 2>/dev/null || echo '')"
            fi
            PNAME="${PNAME:-PID:$pid}"
            write_log "Процесс: $(printf '%-25s' "$PNAME") | Соединений: $cnt"
        done
    else
        write_log "PID процессов недоступны без sudo. Показываем по портам:"
        ss -tn state established 2>/dev/null | awk 'NR>1 {print $4}' | grep -oE ':[0-9]+$' | sort | uniq -c | sort -rn | head -10 | while read -r cnt port; do
            write_log "Порт: $(printf '%-10s' "$port") | Соединений: $cnt"
        done
    fi
elif cmd_exists netstat; then
    # netstat — работает везде (macOS, старые Linux)
    TOTAL_TCP="$(netstat -an 2>/dev/null | grep 'ESTABLISHED' | wc -l | tr -d ' ')"
    write_log "Всего активных TCP-соединений (ESTABLISHED): $TOTAL_TCP"
    if [ "$OS_TYPE" = "Darwin" ]; then
        # macOS: netstat -anv — колонка $9 = размер буфера, НЕ PID!
        # Используем lsof для получения реальных имён процессов + портов назначения
        if cmd_exists lsof; then
            # lsof -i TCP -sTCP:ESTABLISHED = только ESTABLISHED TCP-соединения
            # -n = без DNS резолва, -P = числовые порты, -F cnT = формат: command, name, type
            # Формат вывода lsof -i TCP: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            # Группируем по COMMAND (имя процесса) + remote endpoint
            LSOF_OUTPUT="$(lsof -i TCP -sTCP:ESTABLISHED -n -P 2>/dev/null | tail -n +2)"
            if [ -n "$LSOF_OUTPUT" ]; then
                # Группируем по имени процесса (1-я колонка), показываем топ-10
                echo "$LSOF_OUTPUT" | awk '{print $1}' | sort | uniq -c | sort -rn | head -10 | while read -r cnt pname; do
                    # Показываем также основные remote-адреса для этого процесса
                    REMOTE_PORTS="$(echo "$LSOF_OUTPUT" | awk -v proc="$pname" '$1==proc {print $NF}' | grep -oE '->.*' | sed 's/->//' | cut -d: -f2 | sort | uniq -c | sort -rn | head -3 | awk '{printf ":%s(%s) ", $2, $1}')"
                    write_log "Процесс: $(printf '%-20s' "$pname") | Соединений: $(printf '%-3s' "$cnt") | Порты: ${REMOTE_PORTS:-N/A}"
                done
            else
                write_log "lsof не вернул данных (возможно нет ESTABLISHED-соединений)."
            fi
        else
            # Фоллбэк без lsof: показываем по remote-портам из netstat
            write_log "lsof не найден. Показываем соединения по удалённым портам:"
            netstat -an -p tcp 2>/dev/null | grep 'ESTABLISHED' | awk '{print $5}' | grep -oE '\.[0-9]+$' | sed 's/^\.//' | sort | uniq -c | sort -rn | head -10 | while read -r cnt port; do
                # Пытаемся определить сервис по порту
                case "$port" in
                    443) SVC="HTTPS" ;; 80) SVC="HTTP" ;; 22) SVC="SSH" ;;
                    993) SVC="IMAPS" ;; 5223) SVC="Apple Push" ;; 5228) SVC="Google Play" ;;
                    *) SVC="" ;;
                esac
                write_log "Порт: $(printf '%-5s' "$port") $(printf '%-12s' "${SVC:+($SVC)}") | Соединений: $cnt"
            done
        fi
    else
        # Linux netstat -tnp для PID (может требовать sudo)
        netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | awk '{print $7}' | sort | uniq -c | sort -rn | head -10 | while read -r cnt proc; do
            # proc имеет формат "PID/name" — извлекаем имя
            PROC_PID="$(echo "$proc" | cut -d/ -f1)"
            PROC_NAME="$(echo "$proc" | cut -d/ -f2-)"
            if [ -z "$PROC_NAME" ] || [ "$PROC_NAME" = "-" ]; then
                PROC_NAME="$(cat "/proc/$PROC_PID/comm" 2>/dev/null || echo "PID:$PROC_PID")"
            fi
            write_log "Процесс: $(printf '%-25s' "$PROC_NAME") | Соединений: $cnt"
        done
    fi
fi

# --- Расширения браузеров ---
write_log_header "РАСШИРЕНИЯ БРАУЗЕРОВ"

# Счётчик найденных браузеров (для вывода "не найдено" если пусто)
BROWSERS_FOUND=0

# Функция сканирования расширений Chromium-based браузеров
# Аргументы: $1 = имя браузера, $2 = путь к папке Extensions
scan_chromium_extensions() {
    local browser_name="$1" ext_path="$2"
    # Проверяем что директория существует
    if [ ! -d "$ext_path" ]; then
        return
    fi
    # Проверяем что в ней есть подпапки (расширения)
    local has_extensions=0
    for ext_dir in "$ext_path"/*/; do
        [ -d "$ext_dir" ] && has_extensions=1 && break
    done
    if [ "$has_extensions" -eq 0 ]; then
        return
    fi

    # Браузер найден — увеличиваем счётчик через файл (т.к. вызывается в текущей оболочке)
    BROWSERS_FOUND=$((BROWSERS_FOUND + 1))
    write_log ">>> ${browser_name}:"

    # Перебираем подпапки расширений
    local ext_count=0
    for ext_dir in "$ext_path"/*/; do
        [ -d "$ext_dir" ] || continue
        local ext_id ext_name
        ext_id="$(basename "$ext_dir")"
        ext_name="$ext_id"
        # Пытаемся найти manifest.json и извлечь имя расширения
        local manifest
        manifest="$(find "$ext_dir" -name 'manifest.json' -maxdepth 2 -type f 2>/dev/null | head -1)"
        if [ -n "$manifest" ] && [ -f "$manifest" ]; then
            # Извлекаем "name" из JSON без jq (через grep/sed)
            local parsed_name
            parsed_name="$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" 2>/dev/null | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"//;s/"$//')"
            # Пропускаем __MSG_ (это ссылки на локализацию, не реальное имя)
            if [ -n "$parsed_name" ] && ! echo "$parsed_name" | grep -q '__MSG_'; then
                ext_name="$parsed_name"
            fi
        fi
        write_log "  - $ext_name"
        ext_count=$((ext_count + 1))
    done
    write_log "  Итого расширений: $ext_count"
}

# Определяем домашний каталог пользователя
HOME_DIR="${HOME:-$(eval echo ~)}"

if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: пути к расширениям Chromium-браузеров
    scan_chromium_extensions "Chrome" "$HOME_DIR/Library/Application Support/Google/Chrome/Default/Extensions"
    scan_chromium_extensions "Edge" "$HOME_DIR/Library/Application Support/Microsoft Edge/Default/Extensions"
    scan_chromium_extensions "Opera" "$HOME_DIR/Library/Application Support/com.operasoftware.Opera/Extensions"
    scan_chromium_extensions "Yandex" "$HOME_DIR/Library/Application Support/Yandex/YandexBrowser/Default/Extensions"
    scan_chromium_extensions "Brave" "$HOME_DIR/Library/Application Support/BraveSoftware/Brave-Browser/Default/Extensions"
    scan_chromium_extensions "Vivaldi" "$HOME_DIR/Library/Application Support/Vivaldi/Default/Extensions"

    # --- Safari (macOS) ---
    # Расширения Safari хранятся в .appex-бандлах (бинарный формат),
    # полноценного парсинга без sudo нет, но можем показать список установленных расширений
    SAFARI_EXT_DIR="$HOME_DIR/Library/Containers/com.apple.Safari/Data/Library/Safari/AppExtensions"
    # Также проверяем стандартный путь для Web Extensions (Safari 14+)
    SAFARI_WEB_EXT_DIR="$HOME_DIR/Library/WebKit/WebExtensions"
    SAFARI_FOUND=0
    if [ -d "$SAFARI_EXT_DIR" ]; then
        SAFARI_EXTS="$(ls -1 "$SAFARI_EXT_DIR" 2>/dev/null | sed 's/\.appex$//')"
        if [ -n "$SAFARI_EXTS" ]; then
            BROWSERS_FOUND=$((BROWSERS_FOUND + 1))
            SAFARI_FOUND=1
            write_log ">>> Safari:"
            echo "$SAFARI_EXTS" | while IFS= read -r ext; do
                write_log "  - $ext"
            done
            write_log "  Итого расширений: $(echo "$SAFARI_EXTS" | wc -l | tr -d ' ')"
        fi
    fi
    if [ -d "$SAFARI_WEB_EXT_DIR" ] && [ "$SAFARI_FOUND" -eq 0 ]; then
        SAFARI_WEB_EXTS="$(ls -1 "$SAFARI_WEB_EXT_DIR" 2>/dev/null)"
        if [ -n "$SAFARI_WEB_EXTS" ]; then
            BROWSERS_FOUND=$((BROWSERS_FOUND + 1))
            write_log ">>> Safari (Web Extensions):"
            echo "$SAFARI_WEB_EXTS" | while IFS= read -r ext; do
                write_log "  - $ext"
            done
            write_log "  Итого расширений: $(echo "$SAFARI_WEB_EXTS" | wc -l | tr -d ' ')"
        fi
    fi
else
    # Linux: пути к расширениям Chromium-браузеров (стандартные + flatpak)
    scan_chromium_extensions "Chrome" "$HOME_DIR/.config/google-chrome/Default/Extensions"
    scan_chromium_extensions "Chromium" "$HOME_DIR/.config/chromium/Default/Extensions"
    scan_chromium_extensions "Edge" "$HOME_DIR/.config/microsoft-edge/Default/Extensions"
    scan_chromium_extensions "Opera" "$HOME_DIR/.config/opera/Extensions"
    scan_chromium_extensions "Yandex" "$HOME_DIR/.config/yandex-browser/Default/Extensions"
    scan_chromium_extensions "Brave" "$HOME_DIR/.config/BraveSoftware/Brave-Browser/Default/Extensions"
    scan_chromium_extensions "Vivaldi" "$HOME_DIR/.config/vivaldi/Default/Extensions"
    # Flatpak-версии браузеров
    scan_chromium_extensions "Chrome (Flatpak)" "$HOME_DIR/.var/app/com.google.Chrome/config/google-chrome/Default/Extensions"
    scan_chromium_extensions "Chromium (Flatpak)" "$HOME_DIR/.var/app/org.chromium.Chromium/config/chromium/Default/Extensions"
    scan_chromium_extensions "Edge (Flatpak)" "$HOME_DIR/.var/app/com.microsoft.Edge/config/microsoft-edge/Default/Extensions"
    scan_chromium_extensions "Brave (Flatpak)" "$HOME_DIR/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/Default/Extensions"
fi

# Если ни один Chromium-браузер не найден — сообщаем
if [ "$BROWSERS_FOUND" -eq 0 ]; then
    write_log "Chromium-браузеры (Chrome, Edge, Opera, Yandex, Brave, Vivaldi) не найдены в стандартных путях."
fi

# --- Firefox ---
write_log_header "РАСШИРЕНИЯ FIREFOX"

# Функция сканирования профилей Firefox в указанной директории
# Аргумент: $1 = путь к директории с профилями (Profiles)
scan_firefox_profiles() {
    local profiles_dir="$1"
    [ -d "$profiles_dir" ] || return
    for profile_dir in "$profiles_dir"/*/; do
        [ -d "$profile_dir" ] || continue
        local addons_file="${profile_dir}extensions.json"
        if [ -f "$addons_file" ]; then
            FF_FOUND=1
            local profile_name
            profile_name="$(basename "$profile_dir")"
            write_log "Профиль: $profile_name ($(basename "$profiles_dir"/..))"
            # Парсим extensions.json через awk (разбиваем по },{ на блоки аддонов)
            awk -v RS='},{' '
                /\"type\":\"extension\"/ {
                    name = ""
                    if (match($0, /"name":"[^"]+"/)) {
                        name = substr($0, RSTART+8, RLENGTH-9)
                    }
                    if (name == "" && match($0, /"defaultLocale":\{[^}]*"name":"[^"]+"/)) {
                        tmp = substr($0, RSTART, RLENGTH)
                        if (match(tmp, /"name":"[^"]+"/)) {
                            name = substr(tmp, RSTART+8, RLENGTH-9)
                        }
                    }
                    if (name == "" && match($0, /"id":"[^"]+"/)) {
                        name = substr($0, RSTART+6, RLENGTH-7)
                    }
                    active = "?"
                    if (match($0, /"active":true/)) active = "ВКЛ"
                    else if (match($0, /"active":false/)) active = "ВЫКЛ"
                    version = ""
                    if (match($0, /"version":"[^"]+"/)) {
                        version = substr($0, RSTART+11, RLENGTH-12)
                    }
                    if (name != "" && name !~ /^(Default|Mozilla|Firefox|System)/ && name !~ /mozilla\.org/) {
                        printf "  - [%s] %s (v%s)\n", active, name, version
                    }
                }
            ' "$addons_file" >> "$LOG_FILE" 2>/dev/null
            local ext_count
            ext_count="$(awk -v RS='},{' '/\"type\":\"extension\"/ && !/mozilla\.org/' "$addons_file" 2>/dev/null | wc -l | tr -d ' ')"
            write_log "  Итого расширений в профиле: ${ext_count:-0}"
        fi
    done
}

FF_FOUND=0

# Сканируем все возможные пути к профилям Firefox
if [ "$OS_TYPE" = "Darwin" ]; then
    scan_firefox_profiles "$HOME_DIR/Library/Application Support/Firefox/Profiles"
else
    # Стандартный путь
    scan_firefox_profiles "$HOME_DIR/.mozilla/firefox"
    # Flatpak (SteamOS, Fedora, Ubuntu и др.)
    scan_firefox_profiles "$HOME_DIR/.var/app/org.mozilla.firefox/.mozilla/firefox"
    # Snap (Ubuntu)
    scan_firefox_profiles "$HOME_DIR/snap/firefox/common/.mozilla/firefox"
fi

if [ "$FF_FOUND" -eq 0 ]; then
    # Проверяем есть ли Firefox вообще в системе (через which/command/flatpak)
    FF_EXISTS=0
    if cmd_exists firefox || cmd_exists firefox-esr; then
        FF_EXISTS=1
    elif cmd_exists flatpak && flatpak list 2>/dev/null | grep -qi firefox; then
        FF_EXISTS=1
    elif cmd_exists snap && snap list 2>/dev/null | grep -qi firefox; then
        FF_EXISTS=1
    fi
    if [ "$FF_EXISTS" -eq 1 ]; then
        write_log "Firefox установлен, но файл extensions.json не найден (нет расширений или нестандартный путь профиля)."
        # Подсказка для flatpak
        if cmd_exists flatpak && flatpak list 2>/dev/null | grep -qi firefox; then
            write_log "  (Firefox установлен через Flatpak — профиль ожидается в ~/.var/app/org.mozilla.firefox/.mozilla/firefox/)"
        fi
    else
        write_log "Firefox не установлен или профиль не найден."
    fi
fi
write_status_ok

# ==============================================================================
# --- 6. ТАБЛИЦЫ ---
# ==============================================================================
write_step "6/12" "Маршруты и ARP"

# --- Полная конфигурация IP ---
write_log_header "ПОЛНАЯ КОНФИГУРАЦИЯ IP"
if [ "$OS_TYPE" = "Darwin" ]; then
    ifconfig 2>/dev/null >> "$LOG_FILE"
    # Показываем DNS-серверы из scutil
    scutil --dns 2>/dev/null | grep -E 'nameserver|search domain' >> "$LOG_FILE"
else
    if cmd_exists ip; then
        ip addr show 2>/dev/null >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        # DNS-серверы из resolv.conf
        write_log "DNS серверы (resolv.conf):"
        cat /etc/resolv.conf 2>/dev/null | grep -vE '^\s*#|^\s*$' >> "$LOG_FILE"
    elif cmd_exists ifconfig; then
        ifconfig -a 2>/dev/null >> "$LOG_FILE"
    fi
fi

# --- Таблица маршрутизации ---
write_log_header "ТАБЛИЦА МАРШРУТИЗАЦИИ"
if [ "$OS_TYPE" = "Darwin" ]; then
    netstat -rn 2>/dev/null >> "$LOG_FILE"
else
    if cmd_exists ip; then
        ip route show 2>/dev/null >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        # IPv6 маршруты (default route + первые 10 записей)
        write_log "--- IPv6 маршруты ---"
        ip -6 route show default 2>/dev/null >> "$LOG_FILE"
        ip -6 route show 2>/dev/null | head -10 >> "$LOG_FILE"
    else
        netstat -rn 2>/dev/null >> "$LOG_FILE"
    fi
fi

# --- Таблица ARP ---
write_log_header "ТАБЛИЦА ARP (MAC-АДРЕСА УСТРОЙСТВ)"
if cmd_exists ip; then
    ip neigh show 2>/dev/null >> "$LOG_FILE"
else
    arp -a 2>/dev/null >> "$LOG_FILE"
fi

# --- Диапазон эфемерных портов ---
write_log_header "ЛИМИТЫ ДИНАМИЧЕСКИХ ПОРТОВ (Ephemeral Ports)"
if [ "$OS_TYPE" = "Darwin" ]; then
    sysctl net.inet.ip.portrange.first net.inet.ip.portrange.last 2>/dev/null >> "$LOG_FILE"
else
    if [ -f /proc/sys/net/ipv4/ip_local_port_range ]; then
        write_log "Диапазон: $(cat /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null)"
    fi
fi
write_status_ok

# ==============================================================================
# --- 7. ШЛЮЗ ---
# ==============================================================================
write_step "7/12" "Связь со шлюзом"
write_log_header "ПРОВЕРКА ДОМАШНЕГО ОБОРУДОВАНИЯ (ШЛЮЗ)"

# Получаем IP-адрес(а) шлюза по умолчанию
GATEWAYS=""
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: route -n get default выдаёт gateway
    # Фильтруем ТОЛЬКО IPv4-шлюзы (исключаем fe80:: link-local и другие IPv6)
    GATEWAYS="$(netstat -rn -f inet 2>/dev/null | awk '/^default/ {print $2}' | sort -u)"
else
    if cmd_exists ip; then
        GATEWAYS="$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | sort -u)"
    else
        GATEWAYS="$(netstat -rn 2>/dev/null | awk '/^0\.0\.0\.0/ {print $2}' | sort -u)"
    fi
fi

# Пингуем каждый шлюз 16 раз (только IPv4, с корректным таймаутом)
PING_TIMEOUT_SEC=1
if [ -n "$GATEWAYS" ]; then
    for gw in $GATEWAYS; do
        # Пропускаем невалидные/нулевые адреса
        if [ "$gw" = "0.0.0.0" ] || [ -z "$gw" ]; then continue; fi
        write_log "Тестирование шлюза: $gw"
        # -c 16 = 16 пакетов; do_ping обеспечивает корректный таймаут и IPv4
        do_ping -c 16 "$gw" >> "$LOG_FILE"
    done
else
    write_log "  ! Шлюз по умолчанию не найден."
fi
write_status_ok

# ==============================================================================
# --- 8. DNS / SSL / HTTP ---
# ==============================================================================
write_step "8/12" "DNS, SSL и порты"

# --- Замер скорости DNS ---
write_log_header "АНАЛИЗ DNS"
DNS_SYSTEM="$(measure_dns "" "google.com")"
DNS_EXT="$(measure_dns "$MAIN_DNS" "google.com")"
write_log "Ответ DNS: Системный = ${DNS_SYSTEM}ms | Внешний ($MAIN_DNS) = ${DNS_EXT}ms"

# --- Проверка DNS-спуфинга ---
# Сравниваем IP от системного DNS и от внешнего публичного DNS
# ВАЖНО: CDN-сайты (Google, Cloudflare и т.д.) возвращают разные IP с разных серверов —
# это нормальное поведение anycast/geo-DNS, а НЕ спуфинг.
# Поэтому для проверки используем НЕ-CDN домен (a1.by), а не google.com
DNS_SPOOF=0
DNS_SPOOF_TEST_HOST="a1.by"
SYS_IP="" ; EXT_IP=""
if cmd_exists dig; then
    SYS_IP="$(dig +short "$DNS_SPOOF_TEST_HOST" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1)"
    EXT_IP="$(dig +short @"$MAIN_DNS" "$DNS_SPOOF_TEST_HOST" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1)"
elif cmd_exists host; then
    SYS_IP="$(host -t A "$DNS_SPOOF_TEST_HOST" 2>/dev/null | awk '/has address/ {print $4}' | head -1)"
    EXT_IP="$(host -t A "$DNS_SPOOF_TEST_HOST" "$MAIN_DNS" 2>/dev/null | awk '/has address/ {print $4}' | head -1)"
fi

if [ -n "$SYS_IP" ] && [ -n "$EXT_IP" ]; then
    if [ "$SYS_IP" != "$EXT_IP" ]; then
        # Дополнительная проверка: если IP принадлежат одной /24 подсети — это CDN, не спуфинг
        SYS_SUBNET="$(echo "$SYS_IP" | cut -d. -f1-3)"
        EXT_SUBNET="$(echo "$EXT_IP" | cut -d. -f1-3)"
        if [ "$SYS_SUBNET" = "$EXT_SUBNET" ]; then
            write_log "DNS: IP различаются, но в одной подсети ($SYS_IP vs $EXT_IP) — вероятно балансировка, не спуфинг."
        else
            DNS_SPOOF=1
            write_log "  ! ВНИМАНИЕ: DNS ($DNS_SPOOF_TEST_HOST): Системный=$SYS_IP, Внешний=$EXT_IP — возможен спуфинг!"
        fi
    else
        write_log "DNS спуфинг: Не обнаружен ($DNS_SPOOF_TEST_HOST -> $SYS_IP)"
    fi
else
    write_log "DNS спуфинг: Не удалось проверить (dig/host не вернули результат)"
fi

# --- Подробный анализ DNS ---
write_log_header "АНАЛИЗ СИСТЕМНОГО DNS"
NS_TARGET="${TARGET_SITE:-a1.by}"
write_log "DNS-серверы системы:"
if [ "$OS_TYPE" = "Darwin" ]; then
    scutil --dns 2>/dev/null | grep 'nameserver\[' | sort -u | while IFS= read -r line; do
        write_log "  $line"
    done
else
    grep '^nameserver' /etc/resolv.conf 2>/dev/null | while IFS= read -r line; do
        write_log "  $line"
    done
    # systemd-resolved может иметь свой список DNS и полезную статистику
    if cmd_exists resolvectl; then
        resolvectl status 2>/dev/null | grep -E 'DNS Servers|DNS Domain' | while IFS= read -r line; do
            write_log "  (resolvectl) $line"
        done
        # Статистика кэша DNS (Hit/Miss, ошибки) — доступна без sudo
        RESOLVECTL_STATS="$(resolvectl statistics 2>/dev/null | head -15)"
        if [ -n "$RESOLVECTL_STATS" ]; then
            write_log "--- Статистика DNS-резолвера (systemd-resolved):"
            echo "$RESOLVECTL_STATS" >> "$LOG_FILE"
        fi
    fi
fi

write_log "Запрос DNS для $NS_TARGET:"
if cmd_exists dig; then
    # +nocmd убирает строки вида ";; global options: +cmd" и заголовок dig
    # +noall +answer — показывает только ответы (A/AAAA записи)
    dig "$NS_TARGET" A +nocmd +noall +answer 2>/dev/null >> "$LOG_FILE"
    dig "$NS_TARGET" AAAA +nocmd +noall +answer 2>/dev/null >> "$LOG_FILE"
elif cmd_exists host; then
    host "$NS_TARGET" 2>/dev/null >> "$LOG_FILE"
elif cmd_exists nslookup; then
    nslookup "$NS_TARGET" 2>/dev/null >> "$LOG_FILE"
else
    # Fallback: ping -c1 для резолва
    RESOLVED_IP="$(PING_TIMEOUT_SEC=2 do_ping -c 1 "$NS_TARGET" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')"
    write_log "Resolved (ping fallback): $NS_TARGET -> $RESOLVED_IP"
fi

# --- WHOIS/ASN информация ---
write_log_header "КТО ВЛАДЕЕТ IP (WHOIS/ASN)"
IP_FOR_INFO=""
# Если целевой адрес уже IP — используем как есть
if echo "$MTR_DEST" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
    IP_FOR_INFO="$MTR_DEST"
else
    # Резолвим имя в IP
    if cmd_exists dig; then
        IP_FOR_INFO="$(dig +short "$MTR_DEST" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1)"
    elif cmd_exists host; then
        IP_FOR_INFO="$(host -t A "$MTR_DEST" 2>/dev/null | awk '/has address/ {print $4}' | head -1)"
    else
        IP_FOR_INFO="$(PING_TIMEOUT_SEC=2 do_ping -c 1 "$MTR_DEST" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    fi
fi

IS_CLOUDFLARE=0
if [ -n "$IP_FOR_INFO" ]; then
    # Используем curl для запроса к ip-api.com
    if cmd_exists curl; then
        WHOIS_JSON="$(curl -s --max-time 5 "http://ip-api.com/json/${IP_FOR_INFO}?fields=status,message,isp,as,country,org" 2>/dev/null)"
    elif cmd_exists wget; then
        WHOIS_JSON="$(wget -q -O - --timeout=5 "http://ip-api.com/json/${IP_FOR_INFO}?fields=status,message,isp,as,country,org" 2>/dev/null)"
    else
        WHOIS_JSON=""
        write_log "curl/wget не найдены, WHOIS-запрос невозможен."
    fi

    if [ -n "$WHOIS_JSON" ]; then
        # Парсим JSON: через jq если доступен (100% точный), иначе grep/sed (фоллбэк)
        if cmd_exists jq; then
            WHOIS_STATUS="$(echo "$WHOIS_JSON" | jq -r '.status // empty' 2>/dev/null)"
            WHOIS_ISP="$(echo "$WHOIS_JSON" | jq -r '.isp // empty' 2>/dev/null)"
            WHOIS_AS="$(echo "$WHOIS_JSON" | jq -r '.as // empty' 2>/dev/null)"
            WHOIS_COUNTRY="$(echo "$WHOIS_JSON" | jq -r '.country // empty' 2>/dev/null)"
            WHOIS_ORG="$(echo "$WHOIS_JSON" | jq -r '.org // empty' 2>/dev/null)"
        else
            WHOIS_STATUS="$(echo "$WHOIS_JSON" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"$//')"
            WHOIS_ISP="$(echo "$WHOIS_JSON" | grep -o '"isp":"[^"]*"' | sed 's/"isp":"//;s/"$//')"
            WHOIS_AS="$(echo "$WHOIS_JSON" | grep -o '"as":"[^"]*"' | sed 's/"as":"//;s/"$//')"
            WHOIS_COUNTRY="$(echo "$WHOIS_JSON" | grep -o '"country":"[^"]*"' | sed 's/"country":"//;s/"$//')"
            WHOIS_ORG="$(echo "$WHOIS_JSON" | grep -o '"org":"[^"]*"' | sed 's/"org":"//;s/"$//')"
        fi
        if [ "$WHOIS_STATUS" = "success" ]; then
            ISP_NAME="${WHOIS_ISP:-$WHOIS_ORG}"
            write_log "Узел: $IP_FOR_INFO | Провайдер: $ISP_NAME | Страна: $WHOIS_COUNTRY | ASN: $WHOIS_AS"
            if echo "$ISP_NAME" | grep -qi "Cloudflare"; then
                IS_CLOUDFLARE=1
            fi
        else
            WHOIS_MSG="$(echo "$WHOIS_JSON" | grep -o '"message":"[^"]*"' | sed 's/"message":"//;s/"$//')"
            write_log "Узел: $IP_FOR_INFO | API вернул ошибку: $WHOIS_MSG"
        fi
    fi
else
    write_log "Не удалось определить IP для WHOIS-запроса."
fi

# --- HTTP/SSL анализ ---
write_log_header "АНАЛИЗ HTTP/SSL"
if cmd_exists curl; then
    # HTTP HEAD запрос
    HTTP_RESULT="$(curl -sI --max-time 5 -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' "https://${SSL_TEST_HOST}" 2>&1)"
    HTTP_STATUS="$(echo "$HTTP_RESULT" | head -1)"
    HTTP_SERVER="$(echo "$HTTP_RESULT" | grep -i '^server:' | head -1 | sed 's/[Ss]erver:[[:space:]]*//')"
    write_log "HTTP Status: $HTTP_STATUS"
    if [ -n "$HTTP_SERVER" ]; then
        write_log "Server: $HTTP_SERVER"
    fi

    # SSL-сертификат через curl -v
    SSL_OUTPUT="$(curl -svI --max-time 5 "https://${SSL_TEST_HOST}" 2>&1)"
    SSL_SUBJECT="$(echo "$SSL_OUTPUT" | grep -i 'subject:' | head -1 | sed 's/.*subject: //')"
    SSL_EXPIRE="$(echo "$SSL_OUTPUT" | grep -i 'expire date:' | head -1 | sed 's/.*expire date: //')"
    SSL_ISSUER="$(echo "$SSL_OUTPUT" | grep -i 'issuer:' | head -1 | sed 's/.*issuer: //')"

    if [ -n "$SSL_SUBJECT" ]; then
        write_log "SSL Cert: OK | Кому: $SSL_SUBJECT | Истекает: $SSL_EXPIRE"
        write_log "Издатель: $SSL_ISSUER"
    else
        write_log "SSL: Не удалось получить информацию о сертификате."
    fi
elif cmd_exists openssl; then
    # Фоллбэк: openssl для SSL-информации
    SSL_OUTPUT="$(echo | openssl s_client -connect "${SSL_TEST_HOST}:443" -servername "$SSL_TEST_HOST" 2>/dev/null)"
    if [ -n "$SSL_OUTPUT" ]; then
        SSL_SUBJECT="$(echo "$SSL_OUTPUT" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject= //')"
        SSL_DATES="$(echo "$SSL_OUTPUT" | openssl x509 -noout -dates 2>/dev/null)"
        write_log "SSL Subject: $SSL_SUBJECT"
        write_log "SSL Dates: $SSL_DATES"
    else
        write_log "SSL ОШИБКА: Не удалось подключиться к ${SSL_TEST_HOST}:443"
    fi
fi

# --- Сканирование портов ---
write_log_header "СКАНИРОВАНИЕ ПОРТОВ"
TOP_PORTS="21 22 23 25 53 80 110 139 143 443 445 465 587 993 995 1433 3306 3389 5432 5900 8080 8443"

# Определяем хост для сканирования
PORT_TARGET="${TARGET_SITE:-$MAIN_DNS}"
write_log "Сканирование портов для: $PORT_TARGET"

# Запускаем проверки портов параллельно через фоновые процессы
# Каждый subshell пишет результат в stdout → pipe → файл (атомарно, без race condition)
PORT_RESULTS_FILE="$(mktemp "${TMPDIR:-/tmp}/a1diag_ports.XXXXXX")"

# Запускаем все проверки в фоне, собираем stdout через группирование
{
    for port in $TOP_PORTS; do
        (
            if test_port_quick "$PORT_TARGET" "$port" 1; then
                echo "$port ОТКРЫТ"
            else
                echo "$port ЗАКРЫТ"
            fi
        ) &
    done
    # Ждём завершения всех фоновых задач внутри группы
    wait
} > "$PORT_RESULTS_FILE"

# Сортируем и записываем результаты
if [ -s "$PORT_RESULTS_FILE" ]; then
    sort -n "$PORT_RESULTS_FILE" | while IFS=' ' read -r port status; do
        write_log "Порт: $(printf '%-5s' "$port") | Статус: $status"
    done
fi
rm -f "$PORT_RESULTS_FILE"
write_status_ok

# ==============================================================================
# --- 9. MTR (ТРАССИРОВКА + СТАТИСТИКА) ---
# ==============================================================================
write_step "9/12" "Анализ стабильности (MTR)"
write_log_header "ГЛУБОКИЙ АНАЛИЗ ПУТИ (MTR К $MTR_DEST)"

# --- Резолвим целевой адрес в IP ---
MTR_IP=""
if echo "$MTR_DEST" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
    MTR_IP="$MTR_DEST"
else
    if cmd_exists dig; then
        MTR_IP="$(dig +short "$MTR_DEST" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1)"
    elif cmd_exists host; then
        MTR_IP="$(host -t A "$MTR_DEST" 2>/dev/null | awk '/has address/ {print $4}' | head -1)"
    else
        MTR_IP="$(PING_TIMEOUT_SEC=2 do_ping -c 1 "$MTR_DEST" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    fi
fi
MTR_IP="${MTR_IP:-$MTR_DEST}"

# --- Инициализируем переменные для итогов ---
# По умолчанию "не удалось измерить" — перезапишутся если mtr/traceroute доступен
FIRST_HOP_LOSS="N/A"
FIRST_HOP_JITTER="N/A"

# --- Используем mtr если доступен, иначе traceroute. Без них — НЕ заменяем на ping ---
# Проверяем mtr: на macOS может требовать sudo (raw sockets)
MTR_USABLE=0
if cmd_exists mtr; then
    # Пробуем запустить mtr с минимальным тестом (1 цикл, 1 хоп)
    MTR_TEST="$(mtr -4 --report --report-cycles 1 -m 1 --no-dns "$MTR_IP" 2>&1)"
    MTR_TEST_EXIT=$?
    if [ "$MTR_TEST_EXIT" -eq 0 ] && ! echo "$MTR_TEST" | grep -qi "permission denied\|operation not permitted\|socket\|unable"; then
        MTR_USABLE=1
    else
        write_log "mtr установлен, но требует sudo (raw sockets). Пробуем traceroute..."
    fi
fi

if [ "$MTR_USABLE" -eq 1 ]; then
    MTR_AVAILABLE=1
    # mtr --report делает 30 циклов и выдаёт статистику
    write_log "Используется встроенный mtr (30 циклов)..."
    # Запускаем один раз, сохраняем и в лог и в переменную
    MTR_OUTPUT="$(mtr -4 --report --report-cycles 30 --no-dns "$MTR_IP" 2>/dev/null)"
    echo "$MTR_OUTPUT" >> "$LOG_FILE"

    # Формат строки mtr: HOST Loss% Snt Last Avg Best Wrst StDev
    FIRST_HOP_LOSS="$(echo "$MTR_OUTPUT" | awk 'NR==3 {gsub(/%/,""); print $3}')"
    FIRST_HOP_JITTER="$(echo "$MTR_OUTPUT" | awk 'NR==3 {print $8}')"  # StDev ~ jitter
    FIRST_HOP_LOSS="${FIRST_HOP_LOSS:-0}"
    FIRST_HOP_JITTER="${FIRST_HOP_JITTER:-0}"

elif cmd_exists traceroute; then
    MTR_AVAILABLE=1
    # Фоллбэк: traceroute + серия пингов по хопам
    write_log "mtr не найден или требует sudo. Используется traceroute + серия пингов..."

    # Получаем список хопов через traceroute (UDP по умолчанию, ICMP через -I может требовать root)
    write_log "Трассировка до $MTR_IP..."
    # -n = без DNS, -m 25 = макс 25 хопов, -w 2 = таймаут 2 сек
    # -n = без DNS, -m 25 = макс хопов, -w 2 = таймаут
    # macOS: traceroute не поддерживает -4 (он уже IPv4-only, для IPv6 есть traceroute6)
    # Linux: traceroute поддерживает -4 для принудительного IPv4
    if [ "$OS_TYPE" = "Darwin" ]; then
        TRACE_OUTPUT="$(traceroute -n -m 25 -w 2 "$MTR_IP" 2>/dev/null)"
    else
        TRACE_OUTPUT="$(traceroute -4 -n -m 25 -w 2 "$MTR_IP" 2>/dev/null)"
    fi
    echo "$TRACE_OUTPUT" >> "$LOG_FILE"

    # Извлекаем IP-адреса хопов из вывода traceroute
    # Формат вывода traceroute:
    #   traceroute to 8.8.8.8 (8.8.8.8), 25 hops max, ...   <-- заголовок (пропускаем)
    #    1  192.168.100.1  5.123 ms  ...                      <-- хоп с IP
    #    2  * * *                                              <-- хоп без ответа
    #    3  100.113.0.1  6.141 ms  ...
    # Берём номер хопа из первого поля ($1), IP из второго поля ($2) если оно похоже на IP
    # Пропускаем строки с * * * (нет ответа) и заголовок
    HOP_IPS="$(echo "$TRACE_OUTPUT" | awk '
        # Пропускаем заголовок traceroute (первая строка содержит "traceroute to")
        /^traceroute/ { next }
        {
            # Ищем первый IP-адрес в строке (может быть не во втором поле)
            hop = $1
            for (i = 2; i <= NF; i++) {
                if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                    print hop, $i
                    break
                }
            }
        }
    ')"

    # Проверяем что traceroute вернул хоть какие-то данные
    if [ -z "$TRACE_OUTPUT" ]; then
        write_log "  ! traceroute не вернул данных. Возможные причины:"
        write_log "  !   - Файрвол блокирует исходящие UDP/ICMP пакеты"
        if [ "$OS_TYPE" != "Darwin" ]; then
            write_log "  !   - Флаг -4 не поддерживается данной версией traceroute"
        fi
        write_log "  ! Попробуйте вручную: traceroute -n $MTR_IP"
    fi

    if [ -z "$HOP_IPS" ]; then
        write_log "  ! Не удалось извлечь ни одного хопа с IP-адресом из вывода traceroute."
        write_log "  ! Все промежуточные узлы ответили * * * (таймаут) или traceroute не выполнился."
    fi

    # Пингуем каждый хоп 10 раз для статистики (только если хопы найдены)
    if [ -n "$HOP_IPS" ]; then
    write_log ""
    printf "%-3s | %-15s | %-6s | %-6s | %-6s\n" "Хоп" "IP Адрес" "Отпр." "Пот." "Ср.мс" >> "$LOG_FILE"

    PING_TIMEOUT_SEC=1
    echo "$HOP_IPS" | while IFS=' ' read -r hop_num hop_ip; do
        [ -z "$hop_ip" ] && continue
        # Пингуем хоп 4 раза (IPv4, quiet mode для парсинга статистики)
        # ВАЖНО: не 10, а 4 — промежуточные хопы часто режут ICMP,
        # и 10 таймаутов * 1 сек * N хопов = скрипт зависнет на минуты
        PING_OUTPUT="$(do_ping -c 4 -q "$hop_ip")"
        # Извлекаем статистику из строки ping summary
        # Linux:  "4 packets transmitted, 4 received, 0% packet loss"
        # macOS:  "4 packets transmitted, 4 packets received, 0.0% packet loss"
        # Разница: macOS пишет "packets received", Linux — просто "received"
        SENT="$(echo "$PING_OUTPUT" | grep -oE '[0-9]+ packets transmitted' | grep -oE '^[0-9]+')"
        # Универсальный парсинг received: ищем число перед словом содержащим "received"
        RECV="$(echo "$PING_OUTPUT" | grep 'received' | grep -oE '[0-9]+ (packets )?received' | grep -oE '^[0-9]+')"
        LOSS_PCT="$(echo "$PING_OUTPUT" | grep -oE '[0-9.]+% packet loss' | grep -oE '[0-9.]+')"
        # Среднее время: macOS = "round-trip min/avg/max/stddev = ...", Linux = "rtt min/avg/max/mdev = ..."
        AVG_MS="$(echo "$PING_OUTPUT" | grep -oE '[0-9.]+/[0-9.]+/[0-9.]+/[0-9.]+' | head -1 | cut -d/ -f2)"
        LOST=$((${SENT:-4} - ${RECV:-0}))

        printf "%-3s | %-15s | %-6s | %-6s | %-6s\n" "$hop_num" "$hop_ip" "${SENT:-4}" "$LOST" "${AVG_MS:-*}" >> "$LOG_FILE"

        # Сохраняем данные первого хопа для итогов
        if [ "$hop_num" = "1" ]; then
            # Записываем во временный файл, т.к. мы в подоболочке (pipe)
            echo "${LOSS_PCT:-0}" > "${TMPDIR:-/tmp}/a1_first_hop_loss"
            # mdev — аналог jitter
            MDEV="$(echo "$PING_OUTPUT" | grep -oE '[0-9.]+/[0-9.]+/[0-9.]+/[0-9.]+' | head -1 | cut -d/ -f4)"
            echo "${MDEV:-0}" > "${TMPDIR:-/tmp}/a1_first_hop_jitter"
        fi
    done

    # Читаем данные первого хопа из временных файлов
    if [ -f "${TMPDIR:-/tmp}/a1_first_hop_loss" ]; then
        FIRST_HOP_LOSS="$(cat "${TMPDIR:-/tmp}/a1_first_hop_loss" 2>/dev/null)"
        FIRST_HOP_JITTER="$(cat "${TMPDIR:-/tmp}/a1_first_hop_jitter" 2>/dev/null)"
        rm -f "${TMPDIR:-/tmp}/a1_first_hop_loss" "${TMPDIR:-/tmp}/a1_first_hop_jitter" 2>/dev/null
    fi
    fi  # конец if [ -n "$HOP_IPS" ]
else
    # --- Ни mtr ни traceroute не установлены (или mtr требует sudo) ---
    # НЕ заменяем на ping — он не даёт информации о промежуточных хопах
    write_log "  ! ВНИМАНИЕ: Утилиты mtr и traceroute не установлены (или mtr требует sudo)."
    write_log "  ! Анализ маршрута невозможен. Установите одну из них:"
    if [ "$OS_TYPE" = "Darwin" ]; then
        write_log "  !   macOS: brew install mtr         или  brew install traceroute"
        write_log "  !   (mtr на macOS может потребовать sudo из-за raw sockets)"
    else
        write_log "  !   Ubuntu/Debian: apt install mtr-tiny    или  apt install traceroute"
        write_log "  !   CentOS/RHEL:   yum install mtr         или  yum install traceroute"
        write_log "  !   SteamOS/Arch:  pacman -S mtr           или  pacman -S traceroute"
    fi
    write_log "  ! Данные о потерях на хопах и jitter не будут доступны в итогах."
fi
write_status_ok

# ==============================================================================
# --- 10. СКОРОСТЬ (ЗАГРУЗКА БИНАРНЫХ ФАЙЛОВ) ---
# ==============================================================================
write_step "10/12" "Измерение скорости"
write_log_header "ЗАМЕРЫ СКОРОСТИ"

# --- get_speed: Скачивает файл и измеряет скорость ---
# Аргументы: $1 = URL, $2 = метка (название локации)
# Выводит: скорость в Mbps
get_speed() {
    local url="$1" label="$2"
    local speed_mbps=0

    if cmd_exists curl; then
        # curl: --max-time 15 = ограничение 15 секунд, -o /dev/null = не сохранять
        # -w '%{speed_download}' = скорость в байтах/сек
        local speed_bytes
        speed_bytes="$(curl -s -o /dev/null --max-time 15 -w '%{speed_download}' "$url" 2>/dev/null)"
        if [ -n "$speed_bytes" ] && [ "$speed_bytes" != "0.000" ] 2>/dev/null; then
            # Конвертируем байты/сек в Мбит/сек: speed * 8 / 1000000
            speed_mbps="$(awk "BEGIN {printf \"%.2f\", $speed_bytes * 8 / 1000000}")"
        fi
    elif cmd_exists wget; then
        # wget: замеряем время скачивания первых ~15 МБ
        local start_time end_time downloaded
        start_time="$(date +%s)"
        wget -q -O /dev/null --timeout=15 "$url" 2>/dev/null &
        local wget_pid=$!
        # Ждём 15 секунд или пока завершится
        sleep 15
        kill "$wget_pid" 2>/dev/null
        wait "$wget_pid" 2>/dev/null
        # Без точного размера оценить скорость через wget сложно
        speed_mbps="N/A (wget)"
    fi

    write_log "Локация: $(printf '%-12s' "$label") | Скорость: $speed_mbps Mbps"
    echo "$speed_mbps"
}

write_log "Запуск тестирования скорости (лимит 15 сек на каждый узел)..."

# Запускаем тесты последовательно (параллельно исказят результат)
S1="$(get_speed "https://lg.hosterby.com/1GB.test" "Беларусь")"
S2="$(get_speed "https://speedtest.selectel.ru/1GB" "Россия (МСК)")"
S3="$(get_speed "https://waw-pl-ping.vultr.com/vultr.com.1000MB.bin" "Польша (WAW)")"
S4="$(get_speed "https://fra-de-ping.vultr.com/vultr.com.1000MB.bin" "Европа (FRA)")"
write_status_ok

# ==============================================================================
# --- 11. ПИНГ ЦЕЛЕВЫХ ХОСТОВ + IPv6 ---
# ==============================================================================
write_step "11/12" "Пинг целей и вердикт"
write_log_header "ПИНГ ЦЕЛЕВЫХ ХОСТОВ (IPv4)"

PING_TIMEOUT_SEC=2
for target in $TARGETS; do
    write_log "--- Пинг $target (IPv4) ---"
    # -c 10 = 10 пакетов; do_ping обеспечивает IPv4 + корректный таймаут + verbose
    do_ping -c 10 "$target" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
done

# --- Тест IPv6-связности ---
write_log_header "ПРОВЕРКА IPv6-СВЯЗНОСТИ"
# Определяем команду для ping6 (на Linux это может быть ping -6 или ping6)
PING6_CMD=""
if cmd_exists ping6; then
    PING6_CMD="ping6"
elif ping -6 -c 1 ::1 &>/dev/null; then
    PING6_CMD="ping -6"
fi

if [ -n "$PING6_CMD" ]; then
    # Проверяем есть ли глобальный IPv6-адрес на интерфейсах (не link-local fe80::)
    HAS_GLOBAL_IPV6=0
    if [ "$OS_TYPE" = "Darwin" ]; then
        if ifconfig 2>/dev/null | grep 'inet6' | grep -v 'fe80\|::1' | grep -q 'inet6'; then
            HAS_GLOBAL_IPV6=1
        fi
    else
        if cmd_exists ip; then
            if ip -6 addr show scope global 2>/dev/null | grep -q 'inet6'; then
                HAS_GLOBAL_IPV6=1
            fi
        fi
    fi

    if [ "$HAS_GLOBAL_IPV6" -eq 1 ]; then
        write_log "Глобальный IPv6-адрес обнаружен. Тестирование связности..."
        # Пингуем IPv6-адреса Google и Cloudflare
        IPV6_TARGETS="2001:4860:4860::8888 2606:4700:4700::1111"
        for v6target in $IPV6_TARGETS; do
            write_log "--- IPv6 пинг $v6target ---"
            if [ "$OS_TYPE" = "Darwin" ]; then
                # macOS: ping6 использует -W в миллисекундах, добавляем -v
                $PING6_CMD -v -c 5 -W 2000 "$v6target" 2>&1 >> "$LOG_FILE"
            else
                $PING6_CMD -c 5 -W 2 "$v6target" 2>&1 >> "$LOG_FILE"
            fi
            echo "" >> "$LOG_FILE"
        done
    else
        write_log "Глобальный IPv6-адрес не обнаружен (только link-local). IPv6-связность отсутствует."
    fi
else
    write_log "Утилита ping6 / ping -6 не найдена. Проверка IPv6 невозможна."
fi

# ==============================================================================
# --- ИТОГИ И ЭВРИСТИКА ---
# ==============================================================================
write_log_header "ИТОГОВОЕ РЕЗЮМЕ"

# --- Публичный IP ---
# ВАЖНО: используем -4 чтобы получить именно IPv4 адрес (для корректной проверки CGNAT)
PUB_IP="Error"
PUB_IP6=""
if cmd_exists curl; then
    # Сначала получаем IPv4
    PUB_IP="$(curl -4 -s --max-time 5 http://ifconfig.me/ip 2>/dev/null | tr -d '[:space:]')"
    # Если IPv4 не получен — пробуем без -4 (может вернуть IPv6)
    if [ -z "$PUB_IP" ]; then
        PUB_IP="$(curl -s --max-time 5 http://ifconfig.me/ip 2>/dev/null | tr -d '[:space:]')"
    fi
    # Отдельно пробуем получить IPv6 (если есть)
    PUB_IP6="$(curl -6 -s --max-time 5 http://ifconfig.me/ip 2>/dev/null | tr -d '[:space:]')" || true
elif cmd_exists wget; then
    PUB_IP="$(wget -4 -q -O - --timeout=5 http://ifconfig.me/ip 2>/dev/null | tr -d '[:space:]')"
    if [ -z "$PUB_IP" ]; then
        PUB_IP="$(wget -q -O - --timeout=5 http://ifconfig.me/ip 2>/dev/null | tr -d '[:space:]')"
    fi
fi
[ -z "$PUB_IP" ] && PUB_IP="Error"

# --- Определяем тип IP (белый/серый/CGNAT) ---
# Логика аналогична оригинальному PowerShell: если публичный IP не совпадает с локальным → серый (NAT)
# IS_NAT_TYPE: "none" = белый IP, "cgnat" = CGNAT (100.64.x.x), "nat" = обычный NAT роутера
IS_NAT_TYPE="none"
if [ "$PUB_IP" != "Error" ] && echo "$PUB_IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    # Шаг 1: Проверяем CGNAT диапазон 100.64.0.0/10 (RFC 6598)
    if echo "$PUB_IP" | grep -qE '^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.'; then
        IS_NAT_TYPE="cgnat"
    else
        # Шаг 2: Собираем все локальные IPv4-адреса машины
        LOCAL_IPS=""
        if [ "$OS_TYPE" = "Darwin" ]; then
            LOCAL_IPS="$(ifconfig 2>/dev/null | grep 'inet ' | awk '{print $2}')"
        else
            if cmd_exists ip; then
                LOCAL_IPS="$(ip -4 addr show 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"
            else
                LOCAL_IPS="$(ifconfig 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed 's/addr://')"
            fi
        fi
        # Шаг 3: Если публичный IP НЕ найден среди локальных — это NAT (серый IP)
        # Это может быть как домашний роутер, так и провайдерский NAT
        if [ -n "$LOCAL_IPS" ] && ! echo "$LOCAL_IPS" | grep -qF "$PUB_IP"; then
            IS_NAT_TYPE="nat"
        fi
        # Если публичный IP совпадает с одним из локальных — это белый IP (прямое подключение)
    fi
elif [ "$PUB_IP" != "Error" ]; then
    # Получен не-IPv4 (вероятно IPv6) — не можем определить тип
    write_log "Публичный IPv4 не получен (получено: $PUB_IP). Определение NAT невозможно."
    IS_NAT_TYPE="unknown"
fi

# --- Скорость линка ---
LINK_SPEED_STR="N/A"
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: определяем активный интерфейс и его скорость
    ACTIVE_IF="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
    if [ -n "$ACTIVE_IF" ]; then
        # Способ 1: networksetup -getMedia показывает тип подключения и скорость
        # Сначала находим сетевой сервис по имени интерфейса
        ACTIVE_SERVICE=""
        while IFS= read -r svc; do
            SVC_IF="$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Hardware Port: $svc" | awk '/Device:/ {print $2}')"
            if [ "$SVC_IF" = "$ACTIVE_IF" ]; then
                ACTIVE_SERVICE="$svc"
                break
            fi
        done < <(networksetup -listallnetworkservices 2>/dev/null | tail -n +2)

        # Парсим media из ifconfig
        MEDIA_RAW="$(ifconfig "$ACTIVE_IF" 2>/dev/null | grep 'media:' | head -1 | sed 's/^[[:space:]]*//')"
        MEDIA_STATUS="$(ifconfig "$ACTIVE_IF" 2>/dev/null | grep 'status:' | head -1 | awk '{print $2}')"

        # Формируем читаемую строку
        if echo "$MEDIA_RAW" | grep -qi "1000baseT\|gigabit"; then
            LINK_SPEED_STR="1000 Mbps (Gigabit Ethernet) / ${ACTIVE_IF}"
        elif echo "$MEDIA_RAW" | grep -qi "100baseT"; then
            LINK_SPEED_STR="100 Mbps (Fast Ethernet) / ${ACTIVE_IF}"
        elif echo "$MEDIA_RAW" | grep -qi "10baseT"; then
            LINK_SPEED_STR="10 Mbps / ${ACTIVE_IF}"
        elif echo "$MEDIA_RAW" | grep -qi "autoselect"; then
            # Wi-Fi или автоопределение — показываем тип сервиса
            if [ -n "$ACTIVE_SERVICE" ]; then
                LINK_SPEED_STR="${ACTIVE_SERVICE} (autoselect) / ${ACTIVE_IF} / Status: ${MEDIA_STATUS:-?}"
            else
                LINK_SPEED_STR="Autoselect / ${ACTIVE_IF} / Status: ${MEDIA_STATUS:-?}"
            fi
        else
            LINK_SPEED_STR="${MEDIA_RAW:-N/A} / ${ACTIVE_IF}"
        fi
    fi
else
    # Linux: перебираем активные не-виртуальные интерфейсы
    for iface in $(ip -o link show up 2>/dev/null | awk -F: '{print $2}' | tr -d ' ' | grep -vE '^lo$|^docker|^veth|^br-'); do
        SPEED=""
        DUPLEX=""
        # Способ 1: sysfs
        SPEED_RAW="$(cat /sys/class/net/"$iface"/speed 2>/dev/null)"
        if [ -n "$SPEED_RAW" ] && [ "$SPEED_RAW" != "-1" ] 2>/dev/null; then
            SPEED="$SPEED_RAW"
            DUPLEX="$(cat /sys/class/net/"$iface"/duplex 2>/dev/null || echo 'N/A')"
        fi
        # Способ 2: ethtool
        if [ -z "$SPEED" ] && cmd_exists ethtool; then
            ETH_OUT="$(ethtool "$iface" 2>/dev/null)"
            SPEED="$(echo "$ETH_OUT" | awk '/Speed:/ {gsub(/Mb\/s/,"",$2); print $2}')"
            DUPLEX="$(echo "$ETH_OUT" | awk '/Duplex:/ {print $2}')"
            # ethtool может вернуть "Unknown!" — фильтруем
            if [ "$SPEED" = "Unknown!" ] || [ -z "$SPEED" ]; then
                SPEED=""
            fi
        fi
        if [ -n "$SPEED" ]; then
            LINK_SPEED_STR="${SPEED} Mbps / Duplex: ${DUPLEX:-N/A} (${iface})"
            break  # Нашли первый интерфейс со скоростью
        else
            # Показываем хотя бы что мы нашли интерфейс, но скорость недоступна
            MTU_VAL="$(cat /sys/class/net/"$iface"/mtu 2>/dev/null || echo '?')"
            OPER_STATE="$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo '?')"
            LINK_SPEED_STR="Недоступна (VPS/виртуализация) | ${iface} MTU:${MTU_VAL} State:${OPER_STATE}"
            break
        fi
    done
fi

# --- Формируем выводы ---
CONCLUSIONS=""

add_conclusion() {
    CONCLUSIONS="${CONCLUSIONS}${1}\n"
}

if [ -n "$VPN_DETECTED" ]; then
    add_conclusion "- ВНИМАНИЕ: Активен VPN ($VPN_DETECTED)."
fi
if [ "$IS_WIFI" -eq 1 ]; then
    add_conclusion "- Используется Wi-Fi (возможны помехи)."
    # Для macOS RSSI: вариативность > 10dBm = нестабильно
    VARIATION="$(awk "BEGIN {v=$WIFI_MAX_SIGNAL - ($WIFI_MIN_SIGNAL); if(v<0) v=-v; print v}" 2>/dev/null)"
    if [ "${VARIATION:-0}" -gt 10 ] 2>/dev/null; then
        add_conclusion "- Нестабильный Wi-Fi: сигнал скачет на ${VARIATION}dBm."
    fi
    # Слабый сигнал: RSSI хуже -70 dBm (т.е. число меньше -70)
    AVG_INT="${WIFI_AVG_SIGNAL%%.*}"
    if [ "${AVG_INT:-0}" -lt -70 ] 2>/dev/null; then
        add_conclusion "- Низкий уровень Wi-Fi сигнала (${WIFI_AVG_SIGNAL}dBm). Рекомендуется 5GHz или кабель."
    fi
fi

# Потери на первом хопе (только если удалось замерить)
if [ "$FIRST_HOP_LOSS" != "N/A" ]; then
    FHL_INT="${FIRST_HOP_LOSS%%.*}"
    if [ "${FHL_INT:-0}" -gt 1 ] 2>/dev/null; then
        add_conclusion "- Проблемы на участке ПК-Роутер (потери ${FIRST_HOP_LOSS}%)."
    fi
fi

# Jitter (только если удалось замерить)
if [ "$FIRST_HOP_JITTER" != "N/A" ]; then
    FHJ_INT="${FIRST_HOP_JITTER%%.*}"
    if [ "${FHJ_INT:-0}" -gt 15 ] 2>/dev/null; then
        add_conclusion "- Нестабильный пинг (Джиттер: ${FIRST_HOP_JITTER}ms)."
    fi
fi

if [ "$MTR_AVAILABLE" -eq 0 ]; then
    add_conclusion "- mtr/traceroute не установлены: детальный анализ маршрута не выполнен."
fi

if [ "$MTU_FOUND" -eq 0 ]; then
    add_conclusion "- Обнаружены проблемы с размером MTU (фрагментация или блокировка ICMP)."
fi

if [ "$DNS_SPOOF" -eq 1 ]; then
    add_conclusion "- ВНИМАНИЕ: Обнаружены признаки подмены (спуфинга) DNS."
fi

case "$IS_NAT_TYPE" in
    cgnat)
        add_conclusion "- Используется CGNAT (серый IP, провайдерский NAT 100.64.x.x)." ;;
    nat)
        add_conclusion "- Серый IP (NAT). Публичный IP: $PUB_IP не совпадает с локальным — клиент за роутером/NAT." ;;
    unknown)
        add_conclusion "- Не удалось определить тип IP (IPv4 не получен)." ;;
    *)
        add_conclusion "- Белый (публичный) IP-адрес. $PUB_IP назначен непосредственно интерфейсу (тип: статический или динамический — определяется на стороне провайдера)." ;;
esac

if [ "$IS_CLOUDFLARE" -eq 1 ]; then
    add_conclusion "- Сайт находится за защитой Cloudflare (CDN). Пинг может быть отличным, даже если сервер перегружен."
fi

# --- Формируем строки для потерь и jitter ---
if [ "$FIRST_HOP_LOSS" = "N/A" ]; then
    LOSS_DISPLAY="Не удалось измерить (mtr/traceroute не установлены)"
else
    LOSS_DISPLAY="${FIRST_HOP_LOSS}%"
fi
if [ "$FIRST_HOP_JITTER" = "N/A" ]; then
    JITTER_DISPLAY="Не удалось измерить (mtr/traceroute не установлены)"
else
    JITTER_DISPLAY="${FIRST_HOP_JITTER} ms"
fi

# --- Записываем сводку ---
DOH_STATUS="N/A (проверка DoH в Linux/macOS ограничена)"

# Формируем строку публичного IP (с IPv6 если есть)
PUB_IP_DISPLAY="$PUB_IP"
if [ -n "$PUB_IP6" ] && [ "$PUB_IP6" != "$PUB_IP" ]; then
    PUB_IP_DISPLAY="${PUB_IP} | IPv6: ${PUB_IP6}"
fi

{
    echo ""
    echo "[КРАТКАЯ СВОДКА]"
    echo "Лицевой счет: $ACC_NUM | Публичный IP: $PUB_IP_DISPLAY"
    case "$IS_NAT_TYPE" in
        cgnat)   echo "Тип IP: Серый (CGNAT — провайдерский NAT)" ;;
        nat)     echo "Тип IP: Серый (NAT роутера, публичный IP: $PUB_IP)" ;;
        unknown) echo "Тип IP: Не определён (IPv4 не получен)" ;;
        *)       echo "Тип IP: Белый (публичный, назначен непосредственно интерфейсу)" ;;
    esac
    echo "Виртуализация: $VIRT_TYPE"
    echo "Link Speed: $LINK_SPEED_STR"
    echo "Потери на шлюзе: $LOSS_DISPLAY | Jitter: $JITTER_DISPLAY"
    echo "Скорость (BY/RU/PL/DE): $S1 / $S2 / $S3 / $S4 Mbps"
    echo "DNS Ответ: ${DNS_SYSTEM} ms | Спуфинг: $([ "$DNS_SPOOF" -eq 1 ] && echo 'ДА' || echo 'НЕТ')"
    echo "VPN: $([ -n "$VPN_DETECTED" ] && echo 'АКТИВЕН' || echo 'НЕТ') | DoH: $DOH_STATUS"
    echo "CDN/Protection: $([ "$IS_CLOUDFLARE" -eq 1 ] && echo 'Cloudflare detected' || echo 'None/Direct')"
    echo ""
    echo ">>> ВЫВОДЫ:"
    printf "%b" "$CONCLUSIONS"
} >> "$LOG_FILE"

write_status_ok

# ==============================================================================
# --- 12. ЗАВЕРШЕНИЕ ---
# ==============================================================================
write_step "12/12" "Завершение"

# --- Хэш файла для целостности ---
if cmd_exists sha256sum; then
    # Linux
    HASH="$(sha256sum "$LOG_FILE" | awk '{print $1}')"
elif cmd_exists shasum; then
    # macOS
    HASH="$(shasum -a 256 "$LOG_FILE" | awk '{print $1}')"
else
    HASH="nohash"
fi

# --- Переименовываем файл с хэшем ---
NEW_LOG_FILENAME="A1-${HASH}.txt"
NEW_LOG_FILEPATH="${DIAG_DIR}/${NEW_LOG_FILENAME}"
mv "$LOG_FILE" "$NEW_LOG_FILEPATH" 2>/dev/null || NEW_LOG_FILEPATH="$LOG_FILE"

# --- Звуковое уведомление (BEL) ---
printf '\a'

# --- Пробуем скопировать email в буфер обмена ---
if [ "$OS_TYPE" = "Darwin" ]; then
    echo -n "$SUPPORT_EMAIL" | pbcopy 2>/dev/null
else
    if cmd_exists xclip; then
        echo -n "$SUPPORT_EMAIL" | xclip -selection clipboard 2>/dev/null
    elif cmd_exists xsel; then
        echo -n "$SUPPORT_EMAIL" | xsel --clipboard --input 2>/dev/null
    elif cmd_exists wl-copy; then
        echo -n "$SUPPORT_EMAIL" | wl-copy 2>/dev/null
    fi
fi

# --- Пробуем открыть файловый менеджер с выделением файла ---
if [ "$OS_TYPE" = "Darwin" ]; then
    open -R "$NEW_LOG_FILEPATH" 2>/dev/null
else
    if cmd_exists xdg-open; then
        xdg-open "$DIAG_DIR" 2>/dev/null &
    elif cmd_exists nautilus; then
        nautilus --select "$NEW_LOG_FILEPATH" 2>/dev/null &
    fi
fi

# --- Пробуем открыть почтовый клиент ---
MAIL_SUBJECT="$(printf '%s' "Диагностика ($DIAG_LABEL) - ЛС $ACC_NUM" | sed 's/ /%20/g;s/(/%28/g;s/)/%29/g')"
if [ "$OS_TYPE" = "Darwin" ]; then
    open "mailto:${SUPPORT_EMAIL}?subject=${MAIL_SUBJECT}" 2>/dev/null
else
    if cmd_exists xdg-open; then
        xdg-open "mailto:${SUPPORT_EMAIL}?subject=${MAIL_SUBJECT}" 2>/dev/null &
    fi
fi

write_status_ok

# --- ФИНАЛЬНЫЕ ИНСТРУКЦИИ ДЛЯ ПОЛЬЗОВАТЕЛЯ ---
echo ""
printf "    ${COLOR_GREEN}✅ Диагностика успешно завершена!${COLOR_RESET}\n"
printf "  ${COLOR_GRAY}--------------------------------------------------${COLOR_RESET}\n"
echo "  Мы попытались открыть вашу почту автоматически."
printf "  ${COLOR_YELLOW}Если письмо не появилось, отправьте файл ВРУЧНУЮ:${COLOR_RESET}\n"
echo ""
printf "  1. Кому: ${COLOR_CYAN}%s${COLOR_RESET}" "$SUPPORT_EMAIL"
printf " ${COLOR_GRAY}(адрес скопирован в буфер)${COLOR_RESET}\n"
printf "  2. Файл: ${COLOR_CYAN}%s${COLOR_RESET}" "$NEW_LOG_FILENAME"
printf " ${COLOR_GRAY}(в папке %s)${COLOR_RESET}\n" "$DIAG_DIR"
printf "  3. Тема: ${COLOR_CYAN}Диагностика ЛС %s${COLOR_RESET}\n" "$ACC_NUM"
printf "  ${COLOR_GRAY}--------------------------------------------------${COLOR_RESET}\n"
printf "\n  ${COLOR_YELLOW}Для выхода нажмите клавишу [q] или [Ctrl+C]...${COLOR_RESET}\n"

# Ожидание нажатия клавиши (кроссплатформенно)
while true; do
    # read -n1 читает один символ; -t 1 = таймаут 1 сек (чтобы Ctrl+C работал)
    if IFS= read -rsn1 -t 1 key 2>/dev/null; then
        if [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            break
        fi
    fi
done

echo ""
echo "  Готово. До свидания!"
