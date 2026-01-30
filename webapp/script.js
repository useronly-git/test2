// Тестовые данные товаров
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

// Глобальные переменные
let cart = [];
let currentCategory = 'all';
let currentFilter = 'all';

// Инициализация Telegram Web App
document.addEventListener('DOMContentLoaded', function() {
    // Инициализация Telegram Web App
    if (typeof Telegram !== 'undefined' && Telegram.WebApp) {
        Telegram.WebApp.ready();
        Telegram.WebApp.expand();
        Telegram.WebApp.setHeaderColor('#6F4E37');
        Telegram.WebApp.setBackgroundColor('#FFF9F0');
        Telegram.WebApp.enableClosingConfirmation();

        // Устанавливаем тему Telegram
        const theme = Telegram.WebApp.colorScheme;
        if (theme === 'dark') {
            document.documentElement.style.setProperty('--background', '#1a1a1a');
            document.documentElement.style.setProperty('--surface', '#2d2d2d');
            document.documentElement.style.setProperty('--text-primary', '#ffffff');
            document.documentElement.style.setProperty('--text-secondary', '#cccccc');
            document.documentElement.style.setProperty('--border', '#404040');
        }
    }

    // Инициализация приложения
    initApp();
});

function initApp() {
    // Инициализация меню
    renderMenu(products);

    // Инициализация событий
    initEvents();

    // Восстановление корзины из localStorage
    loadCartFromStorage();

    // Показать приветственное сообщение
    setTimeout(() => {
        showNotification('Добро пожаловать в Coffee Masters!', 'info');
    }, 1000);
}

function initEvents() {
    // Обработчики вкладок
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', function() {
            const category = this.dataset.category;
            switchCategory(category);
        });
    });

    // Обработчики фильтров
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const filter = this.dataset.filter;
            switchFilter(filter);
        });
    });

    // Переключатель типа заказа
    document.getElementById('orderTypeToggle').addEventListener('change', function() {
        updateOrderTypeSummary();
    });

    // Выбор времени заказа
    document.querySelectorAll('input[name="time"]').forEach(radio => {
        radio.addEventListener('change', function() {
            const timePicker = document.getElementById('timePickerContainer');
            timePicker.style.display = this.value === 'later' ? 'block' : 'none';
        });
    });

    // Форма оформления заказа
    document.getElementById('orderForm').addEventListener('submit', function(e) {
        e.preventDefault();
        submitOrder();
    });

    // Закрытие корзины по клику на оверлей
    document.getElementById('cartOverlay').addEventListener('click', closeCart);
    document.getElementById('checkoutOverlay').addEventListener('click', closeCheckout);
}

// Рендер меню
function renderMenu(productsToShow) {
    const container = document.getElementById('menu-container');

    // Если контейнера нет (тестовый режим), создаем его
    if (!container) {
        console.warn('Контейнер меню не найден, работаем в тестовом режиме');
        return;
    }

    container.innerHTML = '';

    if (productsToShow.length === 0) {
        container.innerHTML = `
            <div class="text-center" style="grid-column: 1/-1; padding: 40px 20px;">
                <i class="fas fa-search" style="font-size: 48px; color: var(--text-muted); margin-bottom: 16px;"></i>
                <h3 style="color: var(--text-primary); margin-bottom: 8px;">Товары не найдены</h3>
                <p style="color: var(--text-secondary);">Попробуйте изменить фильтры</p>
            </div>
        `;
        return;
    }

    productsToShow.forEach(product => {
        const isInCart = cart.some(item => item.id === product.id);
        const cartItem = cart.find(item => item.id === product.id);
        const quantityInCart = cartItem ? cartItem.quantity : 0;

        const card = document.createElement('div');
        card.className = 'product-card';

        // Бейджи
        const badges = [];
        if (product.isNew) badges.push('<span class="badge badge-new"><i class="fas fa-star"></i> NEW</span>');
        if (product.popular) badges.push('<span class="badge badge-popular"><i class="fas fa-fire"></i> ПОПУЛЯРНЫЙ</span>');

        // Иконка категории
        let categoryIcon = '☕';
        if (product.type === 'cold') categoryIcon = '🧊';
        if (product.category === 'tea') categoryIcon = '🍵';
        if (product.category === 'desserts') categoryIcon = '🍰';
        if (product.category === 'breakfast') categoryIcon = '🥐';

        // Объем/вес
        const volumeWeight = product.volume || product.weight || '';

        card.innerHTML = `
            ${badges.join('')}
            
            <img src="${product.image}" alt="${product.name}" class="product-image">
            
            <div class="product-content">
                <div class="product-header">
                    <h3 class="product-name">${categoryIcon} ${product.name}</h3>
                    <div class="product-price">${product.price} ₽</div>
                </div>
                
                <p class="product-description">${product.description}</p>
                
                <div class="product-details">
                    <div class="product-volume">
                        <i class="fas fa-weight-hanging"></i> ${volumeWeight}
                    </div>
                    <div class="product-tags">
                        ${product.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
                    </div>
                </div>
                
                <div class="product-footer">
                    <div class="quantity-controls" data-id="${product.id}">
                        <button class="qty-btn minus" onclick="updateProductQuantity(${product.id}, -1)">-</button>
                        <span class="qty-value" id="qty-${product.id}">${quantityInCart}</span>
                        <button class="qty-btn plus" onclick="updateProductQuantity(${product.id}, 1)">+</button>
                    </div>
                    <button class="add-to-cart-btn ${isInCart ? 'in-cart' : ''}" 
                            onclick="addToCart(${product.id})"
                            id="add-btn-${product.id}">
                        <i class="fas ${isInCart ? 'fa-check' : 'fa-plus'}"></i>
                        ${isInCart ? 'В корзине' : 'Добавить'}
                    </button>
                </div>
            </div>
        `;

        container.appendChild(card);
    });
}

// Фильтрация товаров
function filterProducts() {
    let filtered = [...products];

    // Фильтр по категории
    if (currentCategory !== 'all') {
        filtered = filtered.filter(product => product.category === currentCategory);
    }

    // Фильтр по типу
    if (currentFilter !== 'all') {
        if (currentFilter === 'hot') {
            filtered = filtered.filter(product => product.type === 'hot');
        } else if (currentFilter === 'cold') {
            filtered = filtered.filter(product => product.type === 'cold');
        } else if (currentFilter === 'new') {
            filtered = filtered.filter(product => product.isNew);
        } else if (currentFilter === 'popular') {
            filtered = filtered.filter(product => product.popular);
        }
    }

    renderMenu(filtered);
}

// Переключение категории
function switchCategory(category) {
    currentCategory = category;

    // Обновление активной вкладки
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
        if (tab.dataset.category === category) {
            tab.classList.add('active');
        }
    });

    filterProducts();
}

// Переключение фильтра
function switchFilter(filter) {
    currentFilter = filter;

    // Обновление активного фильтра
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.filter === filter) {
            btn.classList.add('active');
        }
    });

    filterProducts();
}

// Корзина
function addToCart(productId) {
    const product = products.find(p => p.id === productId);

    if (!product) {
        showNotification('Товар не найден', 'error');
        return;
    }

    const existingItem = cart.find(item => item.id === productId);

    if (existingItem) {
        existingItem.quantity += 1;
    } else {
        cart.push({
            ...product,
            quantity: 1
        });
    }

    updateCartDisplay();
    saveCartToStorage();

    // Обновление кнопки товара
    const addButton = document.getElementById(`add-btn-${productId}`);
    const qtyElement = document.getElementById(`qty-${productId}`);

    if (addButton && qtyElement) {
        addButton.innerHTML = '<i class="fas fa-check"></i> В корзине';
        addButton.classList.add('in-cart');
        qtyElement.textContent = cart.find(item => item.id === productId).quantity;
    }

    showNotification(`${product.name} добавлен в корзину!`, 'success');
}

function updateProductQuantity(productId, change) {
    const product = products.find(p => p.id === productId);
    const cartItem = cart.find(item => item.id === productId);

    if (!cartItem && change > 0) {
        // Добавляем товар в корзину
        addToCart(productId);
        return;
    }

    if (cartItem) {
        cartItem.quantity += change;

        if (cartItem.quantity <= 0) {
            // Удаляем товар из корзины
            cart = cart.filter(item => item.id !== productId);

            // Обновляем кнопку
            const addButton = document.getElementById(`add-btn-${productId}`);
            const qtyElement = document.getElementById(`qty-${productId}`);

            if (addButton && qtyElement) {
                addButton.innerHTML = '<i class="fas fa-plus"></i> Добавить';
                addButton.classList.remove('in-cart');
                qtyElement.textContent = '0';
            }
        } else {
            // Обновляем количество
            const qtyElement = document.getElementById(`qty-${productId}`);
            if (qtyElement) {
                qtyElement.textContent = cartItem.quantity;
            }
        }

        updateCartDisplay();
        saveCartToStorage();
    }
}

function updateCartDisplay() {
    // Обновляем счетчик корзины
    const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);
    document.getElementById('cart-count').textContent = totalItems;

    // Обновляем кнопку оформления заказа
    const checkoutBtn = document.getElementById('checkout-btn');
    checkoutBtn.disabled = totalItems === 0;

    // Обновляем отображение корзины если она открыта
    if (document.getElementById('cartSidebar').style.right === '0px') {
        renderCartItems();
        updateCartTotal();
    }
}

function renderCartItems() {
    const container = document.getElementById('cart-items');
    const emptyCart = document.getElementById('empty-cart');

    if (cart.length === 0) {
        container.innerHTML = '';
        container.appendChild(emptyCart);
        return;
    }

    container.innerHTML = '';

    cart.forEach(item => {
        const cartItem = document.createElement('div');
        cartItem.className = 'cart-item';

        const subtotal = item.price * item.quantity;

        cartItem.innerHTML = `
            <img src="${item.image}" alt="${item.name}" class="cart-item-image">
            <div class="cart-item-content">
                <div class="cart-item-header">
                    <h4 class="cart-item-name">${item.name}</h4>
                    <div class="cart-item-price">${subtotal} ₽</div>
                </div>
                <p class="cart-item-description">${item.description}</p>
                <div class="cart-item-footer">
                    <div class="cart-item-quantity">
                        <button class="quantity-btn minus" onclick="updateProductQuantity(${item.id}, -1)">-</button>
                        <span class="quantity-value">${item.quantity}</span>
                        <button class="quantity-btn plus" onclick="updateProductQuantity(${item.id}, 1)">+</button>
                    </div>
                    <button class="cart-item-remove" onclick="removeFromCart(${item.id})">
                        <i class="fas fa-trash"></i> Удалить
                    </button>
                </div>
            </div>
        `;

        container.appendChild(cartItem);
    });
}

function removeFromCart(productId) {
    cart = cart.filter(item => item.id !== productId);

    // Обновляем отображение товара в меню
    const addButton = document.getElementById(`add-btn-${productId}`);
    const qtyElement = document.getElementById(`qty-${productId}`);

    if (addButton && qtyElement) {
        addButton.innerHTML = '<i class="fas fa-plus"></i> Добавить';
        addButton.classList.remove('in-cart');
        qtyElement.textContent = '0';
    }

    updateCartDisplay();
    saveCartToStorage();
    showNotification('Товар удален из корзины', 'info');
}

function clearCart() {
    if (cart.length === 0) return;

    if (confirm('Очистить всю корзину?')) {
        // Сбрасываем все счетчики товаров
        cart.forEach(item => {
            const addButton = document.getElementById(`add-btn-${item.id}`);
            const qtyElement = document.getElementById(`qty-${item.id}`);

            if (addButton && qtyElement) {
                addButton.innerHTML = '<i class="fas fa-plus"></i> Добавить';
                addButton.classList.remove('in-cart');
                qtyElement.textContent = '0';
            }
        });

        cart = [];
        updateCartDisplay();
        saveCartToStorage();
        showNotification('Корзина очищена', 'info');
    }
}

function updateCartTotal() {
    const total = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    document.getElementById('total-price').textContent = `${total} ₽`;
}

function openCart() {
    renderCartItems();
    updateCartTotal();

    document.getElementById('cartOverlay').style.display = 'block';
    setTimeout(() => {
        document.getElementById('cartOverlay').style.opacity = '1';
    }, 10);

    document.getElementById('cartSidebar').style.right = '0';
}

function closeCart() {
    document.getElementById('cartOverlay').style.opacity = '0';
    setTimeout(() => {
        document.getElementById('cartOverlay').style.display = 'none';
    }, 300);

    document.getElementById('cartSidebar').style.right = '-100%';
}

// Оформление заказа
function checkout() {
    if (cart.length === 0) {
        showNotification('Добавьте товары в корзину', 'error');
        return;
    }

    closeCart();
    openCheckout();
}

function openCheckout() {
    // Обновляем сводку заказа
    updateOrderSummary();

    // Показываем оверлей
    document.getElementById('checkoutOverlay').style.display = 'block';
    setTimeout(() => {
        document.getElementById('checkoutOverlay').style.opacity = '1';
    }, 10);

    // Показываем модальное окно
    document.getElementById('checkoutModal').style.display = 'block';
    setTimeout(() => {
        document.getElementById('checkoutModal').style.opacity = '1';
        document.getElementById('checkoutModal').style.transform = 'translate(-50%, -50%) scale(1)';
    }, 10);
}

function closeCheckout() {
    document.getElementById('checkoutOverlay').style.opacity = '0';
    document.getElementById('checkoutModal').style.opacity = '0';
    document.getElementById('checkoutModal').style.transform = 'translate(-50%, -50%) scale(0.9)';

    setTimeout(() => {
        document.getElementById('checkoutOverlay').style.display = 'none';
        document.getElementById('checkoutModal').style.display = 'none';
    }, 300);
}

function updateOrderSummary() {
    const summaryContainer = document.getElementById('summary-items');
    const totalElement = document.getElementById('summary-total');

    summaryContainer.innerHTML = '';

    let total = 0;

    cart.forEach(item => {
        const subtotal = item.price * item.quantity;
        total += subtotal;

        const itemElement = document.createElement('div');
        itemElement.className = 'summary-item';
        itemElement.innerHTML = `
            <span class="summary-item-name">${item.name} × ${item.quantity}</span>
            <span class="summary-item-price">${subtotal} ₽</span>
        `;

        summaryContainer.appendChild(itemElement);
    });

    totalElement.textContent = `${total} ₽`;
    updateOrderTypeSummary();
}

function updateOrderTypeSummary() {
    const orderTypeToggle = document.getElementById('orderTypeToggle');
    const orderTypeSummary = document.getElementById('order-type-summary');

    const orderType = orderTypeToggle.checked ? 'Навынос' : 'На месте';
    orderTypeSummary.textContent = orderType;
}

function submitOrder() {
    // Собираем данные формы
    const name = document.getElementById('name').value.trim();
    const phone = document.getElementById('phone').value.trim();
    const timeOption = document.querySelector('input[name="time"]:checked').value;
    const specificTime = document.getElementById('specificTime').value;
    const comment = document.getElementById('comment').value.trim();
    const chatOption = document.querySelector('input[name="chatOption"]:checked').value;
    const orderType = document.getElementById('orderTypeToggle').checked ? 'takeaway' : 'onsite';

    // Валидация
    if (!name || !phone) {
        showNotification('Заполните обязательные поля', 'error');
        return;
    }

    if (timeOption === 'later' && !specificTime) {
        showNotification('Выберите время получения', 'error');
        return;
    }

    // Формируем объект заказа
    const orderData = {
        name,
        phone,
        time: timeOption,
        specificTime: timeOption === 'later' ? specificTime : null,
        comment,
        chatOption,
        orderType,
        items: cart.map(item => ({
            id: item.id,
            name: item.name,
            price: item.price,
            quantity: item.quantity
        })),
        total: cart.reduce((sum, item) => sum + (item.price * item.quantity), 0),
        timestamp: new Date().toISOString(),
        orderId: '#' + Math.random().toString(36).substr(2, 9).toUpperCase()
    };

    // Показываем загрузку
    showNotification('Отправляем заказ...', 'info');

    // Отправляем данные в Telegram бота (если в Web App)
    if (typeof Telegram !== 'undefined' && Telegram.WebApp && Telegram.WebApp.sendData) {
        Telegram.WebApp.sendData(JSON.stringify(orderData));

        // Показываем успешное уведомление
        setTimeout(() => {
            showNotification('Заказ успешно отправлен!', 'success');

            // Очищаем корзину
            clearCart();
            closeCheckout();

            // Закрываем Web App через 2 секунды
            setTimeout(() => {
                if (Telegram.WebApp && Telegram.WebApp.close) {
                    Telegram.WebApp.close();
                }
            }, 2000);
        }, 1500);
    } else {
        // Режим тестирования (без Telegram)
        console.log('Данные заказа (тестовый режим):', orderData);

        setTimeout(() => {
            showNotification('Заказ оформлен! В реальном боте данные отправятся в Telegram.', 'success');

            // Очищаем корзину
            clearCart();
            closeCheckout();
            document.getElementById('orderForm').reset();
        }, 1500);
    }
}

// Уведомления
function showNotification(message, type = 'info') {
    const notifications = document.getElementById('notifications');

    const notification = document.createElement('div');
    notification.className = `notification ${type}`;

    let icon = 'fas fa-info-circle';
    let title = 'Информация';

    if (type === 'success') {
        icon = 'fas fa-check-circle';
        title = 'Успешно';
    } else if (type === 'error') {
        icon = 'fas fa-exclamation-circle';
        title = 'Ошибка';
    }

    notification.innerHTML = `
        <i class="${icon}"></i>
        <div class="notification-content">
            <div class="notification-title">${title}</div>
            <div class="notification-message">${message}</div>
        </div>
    `;

    notifications.appendChild(notification);

    // Автоматическое удаление через 4 секунды
    setTimeout(() => {
        notification.style.animation = 'fadeOut 0.3s ease';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, 4000);
}

// Сохранение в localStorage
function saveCartToStorage() {
    try {
        localStorage.setItem('coffeeCart', JSON.stringify(cart));
    } catch (e) {
        console.warn('Не удалось сохранить корзину в localStorage:', e);
    }
}

function loadCartFromStorage() {
    try {
        const savedCart = localStorage.getItem('coffeeCart');
        if (savedCart) {
            cart = JSON.parse(savedCart);
            updateCartDisplay();

            // Обновляем отображение количества для каждого товара
            cart.forEach(item => {
                const qtyElement = document.getElementById(`qty-${item.id}`);
                const addButton = document.getElementById(`add-btn-${item.id}`);

                if (qtyElement) qtyElement.textContent = item.quantity;
                if (addButton) {
                    addButton.innerHTML = '<i class="fas fa-check"></i> В корзине';
                    addButton.classList.add('in-cart');
                }
            });
        }
    } catch (e) {
        console.warn('Не удалось загрузить корзину из localStorage:', e);
    }
}

// Экспорт функций для глобального использования
window.addToCart = addToCart;
window.updateProductQuantity = updateProductQuantity;
window.removeFromCart = removeFromCart;
window.clearCart = clearCart;
window.checkout = checkout;
window.openCart = openCart;
window.closeCart = closeCart;
window.closeCheckout = closeCheckout;
window.switchCategory = switchCategory;
window.switchFilter = switchFilter;

console.log('Coffee Masters Web App загружен!');
console.log(`Загружено ${products.length} товаров`);