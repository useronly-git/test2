let cart = [];
let products = [];

// Инициализация Telegram Web App
Telegram.WebApp.ready();
Telegram.WebApp.expand();
Telegram.WebApp.setHeaderColor('#6F4E37');
Telegram.WebApp.setBackgroundColor('#FFF9F0');

// Загрузка продуктов
fetch('products.js')
    .then(response => response.json())
    .then(data => {
        products = data;
        renderMenu(products);
    })
    .catch(error => console.error('Error loading products:', error));

// Отображение меню
function renderMenu(productsToShow) {
    const container = document.getElementById('menu-container');
    container.innerHTML = '';

    productsToShow.forEach(product => {
        const card = document.createElement('div');
        card.className = 'product-card';
        card.innerHTML = `
            ${product.isNew ? '<span class="new-badge">NEW</span>' : ''}
            <img src="${product.image}" alt="${product.name}" class="product-image">
            <h3 class="product-title">${product.name}</h3>
            <p class="product-description">${product.description}</p>
            <div class="product-footer">
                <span class="product-price">${product.price} ₽</span>
                <button class="add-to-cart" onclick="addToCart(${product.id})">
                    <i class="fas fa-plus"></i>
                </button>
            </div>
        `;
        container.appendChild(card);
    });
}

// Работа с корзиной
function addToCart(productId) {
    const product = products.find(p => p.id === productId);
    const existingItem = cart.find(item => item.id === productId);

    if (existingItem) {
        existingItem.quantity++;
    } else {
        cart.push({
            ...product,
            quantity: 1
        });
    }

    updateCartCount();
    showNotification(`${product.name} добавлен в корзину!`);
}

function updateCartCount() {
    const total = cart.reduce((sum, item) => sum + item.quantity, 0);
    document.getElementById('cart-count').textContent = total;
}

function openCart() {
    document.getElementById('cartModal').style.display = 'block';
    renderCartItems();
}

function closeCart() {
    document.getElementById('cartModal').style.display = 'none';
}

function renderCartItems() {
    const container = document.getElementById('cart-items');
    container.innerHTML = '';

    if (cart.length === 0) {
        container.innerHTML = '<p class="empty-cart">Корзина пуста</p>';
        document.getElementById('total-price').textContent = '0 ₽';
        return;
    }

    cart.forEach(item => {
        const itemElement = document.createElement('div');
        itemElement.className = 'cart-item';
        itemElement.innerHTML = `
            <div>
                <h4>${item.name}</h4>
                <p>${item.price} ₽ × ${item.quantity}</p>
            </div>
            <div class="cart-item-controls">
                <button onclick="updateQuantity(${item.id}, -1)">-</button>
                <span>${item.quantity}</span>
                <button onclick="updateQuantity(${item.id}, 1)">+</button>
                <button onclick="removeFromCart(${item.id})" style="background: #FF6B6B;">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        `;
        container.appendChild(itemElement);
    });

    updateTotal();
}

function updateTotal() {
    const total = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    document.getElementById('total-price').textContent = `${total} ₽`;
}

function updateQuantity(productId, change) {
    const item = cart.find(item => item.id === productId);
    if (item) {
        item.quantity += change;
        if (item.quantity <= 0) {
            cart = cart.filter(item => item.id !== productId);
        }
        renderCartItems();
        updateCartCount();
    }
}

function removeFromCart(productId) {
    cart = cart.filter(item => item.id !== productId);
    renderCartItems();
    updateCartCount();
}

function clearCart() {
    cart = [];
    renderCartItems();
    updateCartCount();
}

// Оформление заказа
function checkout() {
    if (cart.length === 0) {
        showNotification('Добавьте товары в корзину!');
        return;
    }

    closeCart();
    document.getElementById('checkoutModal').style.display = 'block';
}

function closeCheckout() {
    document.getElementById('checkoutModal').style.display = 'none';
}

// Отправка заказа в Telegram
document.getElementById('orderForm').addEventListener('submit', function(e) {
    e.preventDefault();

    const orderData = {
        name: document.getElementById('name').value,
        phone: document.getElementById('phone').value,
        time: document.querySelector('input[name="time"]:checked').value,
        specificTime: document.getElementById('specificTime').value,
        comment: document.getElementById('comment').value,
        chatOption: document.getElementById('chatOption').value,
        orderType: document.getElementById('orderTypeToggle').checked ? 'takeaway' : 'onsite',
        items: cart,
        total: cart.reduce((sum, item) => sum + (item.price * item.quantity), 0),
        timestamp: new Date().toISOString()
    };

    // Отправка данных в бота
    Telegram.WebApp.sendData(JSON.stringify(orderData));

    // Показать подтверждение
    showNotification('Заказ отправлен!', 'success');

    // Очистить корзину и закрыть формы
    clearCart();
    closeCheckout();
    document.getElementById('orderForm').reset();

    // Закрыть Web App через 2 секунды
    setTimeout(() => {
        Telegram.WebApp.close();
    }, 2000);
});

// Переключение вкладок
function switchTab(category) {
    // Обновить активную вкладку
    document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
    event.target.classList.add('active');

    // Фильтровать продукты
    const filteredProducts = products.filter(product => {
        if (category === 'all') return true;
        return product.category === category;
    });

    renderMenu(filteredProducts);
}

// Уведомления
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${type === 'success' ? '#4CAF50' : '#2196F3'};
        color: white;
        padding: 12px 24px;
        border-radius: 8px;
        z-index: 10000;
        animation: slideIn 0.3s ease;
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// Переключение времени заказа
document.querySelectorAll('input[name="time"]').forEach(radio => {
    radio.addEventListener('change', function() {
        document.getElementById('specificTime').style.display =
            this.value === 'later' ? 'block' : 'none';
    });
});