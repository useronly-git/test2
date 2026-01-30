import json
import uuid
from aiogram import Bot, Dispatcher, types
from aiogram.filters import CommandStart
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
import asyncio
from config import BOT_TOKEN, ORDERS_CHAT_ID, WEBAPP_URL

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()

ORDERS = {}  # order_id -> user_id

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
        "Добро пожаловать в кофейню ☕\nОформите заказ за 1 минуту 👇",
        reply_markup=kb
    )

@dp.message(lambda m: m.web_app_data)
async def receive_order(message: types.Message):
    order = json.loads(message.web_app_data.data)
    order_id = str(uuid.uuid4())[:8]
    ORDERS[order_id] = message.from_user.id

    text = (
        f"🆕 *Новый заказ #{order_id}*\n\n"
        f"👤 {message.from_user.full_name}\n"
        f"📦 {order['type']}\n"
        f"⏰ {order.get('time', 'Как можно скорее')}\n\n"
        "🧾 Заказ:\n"
    )

    total = 0
    for item in order["items"]:
        total += item["price"] * item["qty"]
        text += f"- {item['name']} × {item['qty']}\n"

    text += f"\n💰 Итого: {total} ₽"

    kb = InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(
                text="☕ Начать готовить",
                callback_data=f"cook:{order_id}"
            ),
            InlineKeyboardButton(
                text="✅ Готов",
                callback_data=f"ready:{order_id}"
            )
        ]
    ])

    await bot.send_message(
        ORDERS_CHAT_ID,
        text,
        parse_mode="Markdown",
        reply_markup=kb
    )

    await message.answer("✅ Заказ принят! Мы сообщим, когда он будет готов ☕")

@dp.callback_query(lambda c: c.data.startswith(("cook", "ready")))
async def change_status(callback: types.CallbackQuery):
    action, order_id = callback.data.split(":")
    user_id = ORDERS.get(order_id)

    if not user_id:
        await callback.answer("Заказ не найден")
        return

    if action == "cook":
        await bot.send_message(user_id, f"☕ Ваш заказ #{order_id} начали готовить")
        await callback.answer("Статус: готовится")

    if action == "ready":
        await bot.send_message(user_id, f"✅ Ваш заказ #{order_id} готов! Можно забирать ☕")
        await callback.answer("Статус: готов")

async def main():
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
