import json
from aiogram import Bot, Dispatcher, types
from aiogram.filters import CommandStart
import asyncio
from config import BOT_TOKEN, ORDERS_CHAT_ID, WEBAPP_URL

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()

@dp.message(CommandStart())
async def start(message: types.Message):
    kb = types.ReplyKeyboardMarkup(
        keyboard=[
            [types.KeyboardButton(
                text="☕ Сделать заказ",
                web_app=types.WebAppInfo(url=WEBAPP_URL)
            )]
        ],
        resize_keyboard=True
    )
    await message.answer(
        "Привет! ☕\nЗакажи кофе навынос или на месте 👇",
        reply_markup=kb
    )

@dp.message(lambda m: m.web_app_data)
async def receive_order(message: types.Message):
    order = json.loads(message.web_app_data.data)

    text = (
        "☕ *Новый заказ*\n\n"
        f"👤 Клиент: {message.from_user.full_name}\n"
        f"📦 Тип: {order['type']}\n"
        f"⏰ Время: {order.get('time', 'как можно скорее')}\n\n"
        "🧾 Заказ:\n"
    )

    total = 0
    for item in order["items"]:
        text += f"- {item['name']} × {item['qty']} = {item['price'] * item['qty']} ₽\n"
        total += item['price'] * item['qty']

    text += f"\n💰 Итого: {total} ₽"

    await bot.send_message(
        ORDERS_CHAT_ID,
        text,
        parse_mode="Markdown"
    )

    await message.answer("✅ Заказ принят! Скоро начнём готовить ☕")

async def main():
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
