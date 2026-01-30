import sys
import os

# Добавляем корневую директорию в путь Python
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Теперь импортируем config
try:
    from config import BOT_TOKEN, WEBAPP_URL

    print(f"✅ Конфигурация загружена успешно")
    print(f"   BOT_TOKEN: {'Установлен' if BOT_TOKEN else 'ОТСУТСТВУЕТ!'}")
except ImportError as e:
    print(f"❌ Ошибка импорта config: {e}")
    print("Убедитесь, что config.py находится в корне проекта")
    sys.exit(1)

import logging
from aiogram import Bot, Dispatcher, types
from aiogram.filters import Command
from aiogram.types import WebAppInfo, InlineKeyboardMarkup, InlineKeyboardButton
import asyncio

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Проверяем токен
if not BOT_TOKEN:
    logger.error("""
    ⚠️ BOT_TOKEN не задан!

    Создайте файл .env в корне проекта со следующим содержимым:

    BOT_TOKEN=ваш_токен_бота_от_BotFather

    Пример:
    BOT_TOKEN=7123456789:AAHdF0hVx_123456789abcdefghijklmnopq

    Или запустите бота с параметром:
    python main.py --token ВАШ_ТОКЕН
    """)
    sys.exit(1)

# Инициализация бота
try:
    bot = Bot(token=BOT_TOKEN)
    dp = Dispatcher()
    logger.info(f"Бот успешно инициализирован")
except Exception as e:
    logger.error(f"Ошибка инициализации бота: {e}")
    sys.exit(1)


# Простая команда start для теста
@dp.message(Command("start"))
async def start_command(message: types.Message):
    # Простая клавиатура без Web App (для теста)
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📱 Открыть меню", callback_data="open_menu")],
        [InlineKeyboardButton(text="📞 Контакты", callback_data="contacts")],
        [InlineKeyboardButton(text="ℹ️ О нас", callback_data="about")]
    ])

    await message.answer(
        "☕ Добро пожаловать в нашу кофейню!\n\n"
        "Я - тестовый бот для заказа кофе.\n"
        f"Токен: {'✅ Настроен' if BOT_TOKEN else '❌ Отсутствует'}\n"
        f"Web App URL: {WEBAPP_URL}",
        reply_markup=keyboard
    )


@dp.callback_query(lambda c: c.data == "open_menu")
async def open_menu(callback: types.CallbackQuery):
    await callback.answer("Меню скоро будет доступно!")

    # Если Web App URL настроен, показываем кнопку
    if WEBAPP_URL and WEBAPP_URL != 'https://ваш-сайт.com/webapp/':
        keyboard = InlineKeyboardMarkup(inline_keyboard=[
            [InlineKeyboardButton(
                text="📱 Открыть интерактивное меню",
                web_app=WebAppInfo(url=WEBAPP_URL)
            )]
        ])
        await callback.message.answer("Нажмите кнопку ниже для открытия меню:", reply_markup=keyboard)
    else:
        await callback.message.answer(
            "⚠️ Web App URL не настроен!\n"
            "Добавьте в .env файл:\n"
            "WEBAPP_URL=https://ваш-реальный-сайт.com/"
        )


@dp.message(Command("test"))
async def test_command(message: types.Message):
    """Тестовая команда для проверки работы бота"""
    await message.answer(f"✅ Бот работает!\nТокен: {'Настроен' if BOT_TOKEN else 'НЕ настроен'}")


@dp.message(Command("help"))
async def help_command(message: types.Message):
    """Команда помощи"""
    help_text = """
    📚 Доступные команды:

    /start - Начать работу с ботом
    /test - Проверить работу бота
    /help - Показать это сообщение

    💡 Для настройки Web App:
    1. Разместите папку webapp на хостинге
    2. Добавьте в .env файл:
       WEBAPP_URL=https://ваш-сайт.com/
    3. Перезапустите бота
    """
    await message.answer(help_text)


async def main():
    try:
        logger.info("Запуск бота...")
        # Проверяем соединение с Telegram
        me = await bot.get_me()
        logger.info(f"Бот запущен: @{me.username} ({me.first_name})")

        # Запускаем polling
        await dp.start_polling(bot)
    except Exception as e:
        logger.error(f"Ошибка запуска бота: {e}")
    finally:
        await bot.session.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Бот остановлен")