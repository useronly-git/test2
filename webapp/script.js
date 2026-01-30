// В начале файла script.js добавьте:
function renderMenu(productsToShow) {
    const container = document.getElementById('menu-container');
    container.innerHTML = '';
    
    productsToShow.forEach(product => {
        const card = document.createElement('div');
        card.className = 'product-card';
        
        // Определяем иконку в зависимости от типа
        let typeIcon = '☕';
        if (product.type === 'cold') typeIcon = '🧊';
        if (product.type === 'food') typeIcon = '🍰';
        if (product.category === 'tea') typeIcon = '🍵';
        if (product.category === 'breakfast') typeIcon = '🥐';
        
        // Определяем объем/вес
        const volumeWeight = product.volume || product.weight || '';
        
        card.innerHTML = `
            ${product.isNew ? '<span class="new-badge">NEW</span>' : ''}
            ${product.popular ? '<span class="popular-badge">🔥</span>' : ''}
            
            <div class="product-image-container">
                <img src="${product.image}" alt="${product.name}" class="product-image">
                <div class="product-type-icon">${typeIcon}</div>
            </div>
            
            <div class="product-info">
                <div class="product-header">
                    <h3 class="product-title">${product.name}</h3>
                    <span class="product-price">${product.price} ₽</span>
                </div>
                
                <p class="product-description">${product.description}</p>
                
                <div class="product-details">
                    <span class="product-volume">${volumeWeight}</span>
                    <div class="product-tags">
                        ${product.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
                    </div>
                </div>
                
                <div class="product-footer">
                    <div class="quantity-controls" data-id="${product.id}">
                        <button class="qty-btn minus" onclick="updateQuantity(${product.id}, -1)">-</button>
                        <span class="qty-value" id="qty-${product.id}">0</span>
                        <button class="qty-btn plus" onclick="updateQuantity(${product.id}, 1)">+</button>
                    </div>
                    <button class="add-to-cart-btn" onclick="addToCart(${product.id})">
                        <i class="fas fa-plus"></i> Добавить
                    </button>
                </div>
            </div>
        `;
        container.appendChild(card);
    });
}

// Добавьте этот CSS в style.css
const additionalCSS = `
.product-image-container {
    position: relative;
    margin-bottom: 10px;
}

.product-type-icon {
    position: absolute;
    top: 10px;
    left: 10px;
    background: rgba(111, 78, 55, 0.9);
    color: white;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
}

.product-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 8px;
}

.product-info {
    display: flex;
    flex-direction: column;
    height: 100%;
}

.product-details {
    margin-top: auto;
    padding-top: 10px;
    border-top: 1px solid #eee;
}

.product-volume {
    display: block;
    color: #666;
    font-size: 14px;
    margin-bottom: 8px;
}

.product-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-bottom: 12px;
}

.tag {
    background: #f0f0f0;
    color: #666;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 12px;
}

.quantity-controls {
    display: flex;
    align-items: center;
    gap: 8px;
}

.qty-btn {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    border: 2px solid var(--secondary-color);
    background: white;
    color: var(--secondary-color);
    font-weight: bold;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
}

.qty-value {
    min-width: 20px;
    text-align: center;
    font-weight: bold;
}

.add-to-cart-btn {
    padding: 8px 16px;
    background: var(--primary-color);
    color: white;
    border: none;
    border-radius: 20px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 6px;
    transition: background 0.3s;
}

.add-to-cart-btn:hover {
    background: #5a3d2c;
}

.popular-badge {
    position: absolute;
    top: 15px;
    right: 15px;
    background: #FF6B6B;
    color: white;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 16px;
    z-index: 1;
}
`;

// Добавьте стили на страницу
const styleSheet = document.createElement("style");
styleSheet.textContent = additionalCSS;
document.head.appendChild(styleSheet);

// Обновите функцию addToCart для отслеживания количества
let cartQuantities = {};

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
    
    // Обновляем счетчик на кнопке
    cartQuantities[productId] = (cartQuantities[productId] || 0) + 1;
    updateQuantityDisplay(productId);
    
    updateCartCount();
    showNotification(`${product.name} добавлен в корзину!`);
}

function updateQuantity(productId, change) {
    const currentQty = cartQuantities[productId] || 0;
    const newQty = Math.max(0, currentQty + change);
    cartQuantities[productId] = newQty;
    
    // Обновляем отображение
    updateQuantityDisplay(productId);
    
    // Если количество > 0, обновляем корзину
    if (newQty > 0) {
        // Находим товар в корзине или добавляем
        const product = products.find(p => p.id === productId);
        const existingItem = cart.find(item => item.id === productId);
        
        if (existingItem) {
            existingItem.quantity = newQty;
        } else {
            cart.push({
                ...product,
                quantity: newQty
            });
        }
    } else {
        // Удаляем из корзины если количество 0
        cart = cart.filter(item => item.id !== productId);
        delete cartQuantities[productId];
    }
    
    updateCartCount();
}

function updateQuantityDisplay(productId) {
    const qtyElement = document.getElementById(`qty-${productId}`);
    if (qtyElement) {
        const qty = cartQuantities[productId] || 0;
        qtyElement.textContent = qty;
        
        // Меняем цвет кнопки если товар в корзине
        const addButton = qtyElement.closest('.product-footer').querySelector('.add-to-cart-btn');
        if (qty > 0) {
            addButton.innerHTML = '<i class="fas fa-check"></i> В корзине';
            addButton.style.background = '#4CAF50';
        } else {
            addButton.innerHTML = '<i class="fas fa-plus"></i> Добавить';
            addButton.style.background = 'var(--primary-color)';
        }
    }
}