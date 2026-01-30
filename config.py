import os
from pathlib import Path
from dotenv import load_dotenv

# Получаем путь к корню проекта
BASE_DIR = Path(__file__).parent

# Загрузка .env файла
env_path = BASE_DIR / '.env'
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
    print(f".env файл загружен из: {env_path}")
else:
    print("ВНИМАНИЕ: .env файл не найден!")

# Токен бота - обязательный параметр
BOT_TOKEN = os.getenv('BOT_TOKEN')

if not BOT_TOKEN:
    print("""
    ⚠️ ВНИМАНИЕ: BOT_TOKEN не найден!

    Создайте файл .env в корне проекта со следующим содержимым:

    BOT_TOKEN=ваш_токен_бота_от_BotFather

    Как получить токен:
    1. Откройте Telegram
    2. Найдите @BotFather
    3. Создайте нового бота: /newbot
    4. Скопируйте токен
    """)

# Web App URL (можно оставить пустым для тестов)
WEBAPP_URL = os.getenv('WEBAPP_URL', 'https://ваш-сайт.com/webapp/')

# ID чата администратора (опционально)
ADMIN_CHAT_ID = os.getenv('ADMIN_CHAT_ID')

# Настройки базы данных
DATABASE_PATH = BASE_DIR / 'coffee.db'

print(f"Конфигурация загружена. База данных: {DATABASE_PATH}")