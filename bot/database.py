import sqlite3
from datetime import datetime


class Database:
    def __init__(self, db_name='coffee.db'):
        self.conn = sqlite3.connect(db_name)
        self.create_tables()

    def create_tables(self):
        cursor = self.conn.cursor()

        # Таблица пользователей
        cursor.execute('''
                       CREATE TABLE IF NOT EXISTS users
                       (
                           user_id
                           INTEGER
                           PRIMARY
                           KEY,
                           username
                           TEXT,
                           first_name
                           TEXT,
                           last_name
                           TEXT,
                           phone
                           TEXT,
                           created_at
                           TIMESTAMP
                           DEFAULT
                           CURRENT_TIMESTAMP
                       )
                       ''')

        # Таблица заказов
        cursor.execute('''
                       CREATE TABLE IF NOT EXISTS orders
                       (
                           order_id
                           INTEGER
                           PRIMARY
                           KEY
                           AUTOINCREMENT,
                           user_id
                           INTEGER,
                           order_data
                           TEXT,
                           total_price
                           REAL,
                           order_type
                           TEXT,
                           order_time
                           TEXT,
                           status
                           TEXT
                           DEFAULT
                           'pending',
                           created_at
                           TIMESTAMP
                           DEFAULT
                           CURRENT_TIMESTAMP,
                           FOREIGN
                           KEY
                       (
                           user_id
                       ) REFERENCES users
                       (
                           user_id
                       )
                           )
                       ''')

        self.conn.commit()

    def save_order(self, user_id: int, order_data: dict):
        cursor = self.conn.cursor()

        # Сохраняем пользователя
        cursor.execute('''
                       INSERT
                       OR IGNORE INTO users (user_id) VALUES (?)
                       ''', (user_id,))

        # Сохраняем заказ
        cursor.execute('''
                       INSERT INTO orders (user_id, order_data, total_price, order_type, order_time)
                       VALUES (?, ?, ?, ?, ?)
                       ''', (
                           user_id,
                           json.dumps(order_data),
                           order_data['total'],
                           order_data['orderType'],
                           order_data.get('specificTime', 'now')
                       ))

        self.conn.commit()
        return cursor.lastrowid