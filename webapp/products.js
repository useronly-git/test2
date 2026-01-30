// Тестовые данные для кофейни
const products = [
    // Кофе горячий
    {
        "id": 1,
        "name": "Эспрессо",
        "price": 180,
        "category": "coffee",
        "type": "hot",
        "description": "Классический крепкий кофе, 30 мл",
        "image": "https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?w=400&h=300&fit=crop",
        "volume": "30 мл",
        "isNew": false,
        "popular": true,
        "tags": ["классика", "крепкий"]
    },
    {
        "id": 2,
        "name": "Двойной эспрессо",
        "price": 220,
        "category": "coffee",
        "type": "hot",
        "description": "Двойная порция классического эспрессо",
        "image": "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400&h=300&fit=crop",
        "volume": "60 мл",
        "isNew": false,
        "popular": true,
        "tags": ["двойной", "бодрящий"]
    },
    {
        "id": 3,
        "name": "Американо",
        "price": 200,
        "category": "coffee",
        "type": "hot",
        "description": "Эспрессо с добавлением горячей воды",
        "image": "https://images.unsplash.com/photo-1561047029-3000c68339ca?w=400&h=300&fit=crop",
        "volume": "180 мл",
        "isNew": false,
        "popular": true,
        "tags": ["нежный", "ароматный"]
    },
    {
        "id": 4,
        "name": "Капучино",
        "price": 280,
        "category": "coffee",
        "type": "hot",
        "description": "Идеальный баланс кофе, молока и пенки",
        "image": "https://images.unsplash.com/photo-1534778101976-62847782c213?w=400&h=300&fit=crop",
        "volume": "200 мл",
        "isNew": false,
        "popular": true,
        "tags": ["молочный", "нежный"]
    },
    {
        "id": 5,
        "name": "Латте",
        "price": 300,
        "category": "coffee",
        "type": "hot",
        "description": "Больше молока, мягкий вкус, нежная пенка",
        "image": "https://images.unsplash.com/photo-1570196911496-66bd58a5b7b4?w=400&h=300&fit=crop",
        "volume": "250 мл",
        "isNew": true,
        "popular": true,
        "tags": ["молочный", "нежный", "новинка"]
    },
    {
        "id": 6,
        "name": "Флэт Уайт",
        "price": 290,
        "category": "coffee",
        "type": "hot",
        "description": "Двойной эспрессо с микропенкой",
        "image": "https://images.unsplash.com/photo-1510707577715-2c3c3b7f5b3c?w=400&h=300&fit=crop",
        "volume": "180 мл",
        "isNew": true,
        "popular": false,
        "tags": ["крепкий", "микропена", "новинка"]
    },
    {
        "id": 7,
        "name": "Раф кофе",
        "price": 320,
        "category": "coffee",
        "type": "hot",
        "description": "Кофе со сливками и ванильным сиропом",
        "image": "https://images.unsplash.com/photo-1587734195507-6f5e8a2543c4?w=400&h=300&fit=crop",
        "volume": "250 мл",
        "isNew": false,
        "popular": true,
        "tags": ["сладкий", "сливочный", "ваниль"]
    },
    {
        "id": 8,
        "name": "Мокачино",
        "price": 310,
        "category": "coffee",
        "type": "hot",
        "description": "Кофе с шоколадом и молочной пенкой",
        "image": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop",
        "volume": "220 мл",
        "isNew": false,
        "popular": false,
        "tags": ["шоколадный", "сладкий"]
    },

    // Кофе холодный
    {
        "id": 9,
        "name": "Айс Американо",
        "price": 220,
        "category": "coffee",
        "type": "cold",
        "description": "Холодный американо со льдом",
        "image": "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&h=300&fit=crop",
        "volume": "300 мл",
        "isNew": false,
        "popular": true,
        "tags": ["освежающий", "летний"]
    },
    {
        "id": 10,
        "name": "Айс Латте",
        "price": 330,
        "category": "coffee",
        "type": "cold",
        "description": "Холодный латте со льдом",
        "image": "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=300&fit=crop",
        "volume": "350 мл",
        "isNew": false,
        "popular": true,
        "tags": ["молочный", "летний"]
    },
    {
        "id": 11,
        "name": "Колд Брю",
        "price": 350,
        "category": "coffee",
        "type": "cold",
        "description": "Кофе холодного заваривания",
        "image": "https://images.unsplash.com/photo-1553909489-cd47e0907980?w=400&h=300&fit=crop",
        "volume": "300 мл",
        "isNew": true,
        "popular": false,
        "tags": ["холодное заваривание", "новинка"]
    },
    {
        "id": 12,
        "name": "Фраппучино",
        "price": 380,
        "category": "coffee",
        "type": "cold",
        "description": "Взбитый холодный кофе со льдом",
        "image": "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&h=300&fit=crop",
        "volume": "400 мл",
        "isNew": true,
        "popular": true,
        "tags": ["взбитый", "летний", "новинка"]
    },

    // Чай
    {
        "id": 13,
        "name": "Черный чай",
        "price": 150,
        "category": "tea",
        "type": "hot",
        "description": "Классический черный чай",
        "image": "https://images.unsplash.com/photo-1564890369478-c89ca2d9c423?w=400&h=300&fit=crop",
        "volume": "250 мл",
        "isNew": false,
        "popular": false,
        "tags": ["классика", "чай"]
    },
    {
        "id": 14,
        "name": "Зеленый чай",
        "price": 160,
        "category": "tea",
        "type": "hot",
        "description": "Свежий зеленый чай",
        "image": "https://images.unsplash.com/photo-1597481499755-58e5e8e0b8c8?w=400&h=300&fit=crop",
        "volume": "250 мл",
        "isNew": false,
        "popular": true,
        "tags": ["зеленый", "чай"]
    },
    {
        "id": 15,
        "name": "Чай с бергамотом",
        "price": 180,
        "category": "tea",
        "type": "hot",
        "description": "Черный чай с ароматом бергамота",
        "image": "https://images.unsplash.com/photo-1576092768241-dec1383d8c54?w=400&h=300&fit=crop",
        "volume": "250 мл",
        "isNew": false,
        "popular": false,
        "tags": ["ароматный", "чай"]
    },
    {
        "id": 16,
        "name": "Ягодный чай",
        "price": 200,
        "category": "tea",
        "type": "hot",
        "description": "Фруктовый чай с ягодами",
        "image": "https://images.unsplash.com/photo-1560343090-f0409e92791a?w=400&h=300&fit=crop",
        "volume": "250 мл",
        "isNew": true,
        "popular": true,
        "tags": ["фруктовый", "ягодный", "новинка"]
    },

    // Десерты
    {
        "id": 17,
        "name": "Круассан",
        "price": 180,
        "category": "desserts",
        "type": "food",
        "description": "Свежий французский круассан",
        "image": "https://images.unsplash.com/photo-1555507036-ab794f27d2e9?w=400&h=300&fit=crop",
        "weight": "80 г",
        "isNew": false,
        "popular": true,
        "tags": ["выпечка", "сладкий"]
    },
    {
        "id": 18,
        "name": "Чизкейк Нью-Йорк",
        "price": 320,
        "category": "desserts",
        "type": "food",
        "description": "Классический чизкейк",
        "image": "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=400&h=300&fit=crop",
        "weight": "150 г",
        "isNew": false,
        "popular": true,
        "tags": ["чизкейк", "классика"]
    },
    {
        "id": 19,
        "name": "Тирамису",
        "price": 350,
        "category": "desserts",
        "type": "food",
        "description": "Итальянский десерт с кофе",
        "image": "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=400&h=300&fit=crop",
        "weight": "150 г",
        "isNew": true,
        "popular": true,
        "tags": ["итальянский", "кофейный", "новинка"]
    },
    {
        "id": 20,
        "name": "Макарон",
        "price": 120,
        "category": "desserts",
        "type": "food",
        "description": "Французское пирожное",
        "image": "https://images.unsplash.com/photo-1569929238190-869dfc6a8e41?w=400&h=300&fit=crop",
        "weight": "30 г",
        "isNew": false,
        "popular": false,
        "tags": ["пирожное", "нежное"]
    },

    // Завтраки
    {
        "id": 21,
        "name": "Сырники",
        "price": 280,
        "category": "breakfast",
        "type": "food",
        "description": "Творожные сырники со сметаной",
        "image": "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400&h=300&fit=crop",
        "weight": "200 г",
        "isNew": false,
        "popular": true,
        "tags": ["завтрак", "творог"]
    },
    {
        "id": 22,
        "name": "Омлет с овощами",
        "price": 250,
        "category": "breakfast",
        "type": "food",
        "description": "Омлет со свежими овощами",
        "image": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=300&fit=crop",
        "weight": "250 г",
        "isNew": false,
        "popular": false,
        "tags": ["завтрак", "яйца"]
    },
    {
        "id": 23,
        "name": "Гранола с йогуртом",
        "price": 220,
        "category": "breakfast",
        "type": "food",
        "description": "Хрустящая гранола с греческим йогуртом",
        "image": "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=300&fit=crop",
        "weight": "200 г",
        "isNew": true,
        "popular": true,
        "tags": ["завтрак", "здоровый", "новинка"]
    },
    {
        "id": 24,
        "name": "Авокадо-тост",
        "price": 300,
        "category": "breakfast",
        "type": "food",
        "description": "Тост с авокадо и яйцом-пашот",
        "image": "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400&h=300&fit=crop",
        "weight": "180 г",
        "isNew": true,
        "popular": true,
        "tags": ["завтрак", "авокадо", "новинка"]
    }
];

// Экспорт для использования в других файлах
if (typeof module !== 'undefined' && module.exports) {
    module.exports = products;
}