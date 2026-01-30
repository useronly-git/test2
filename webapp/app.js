const tg = Telegram.WebApp;
tg.expand();

let cart = {};
let total = 0;

fetch("/menu.json")
  .then(r => r.json())
  .then(data => renderMenu(data.categories));

function renderMenu(categories) {
  const root = document.getElementById("menu");

  categories.forEach(cat => {
    root.innerHTML += `<div class="category">${cat.name}</div>`;

    cat.items.forEach(item => {
      cart[item.id] = { ...item, qty: 0 };

      root.innerHTML += `
        <div class="item">
          <div>
            <div class="item-name">${item.name}</div>
            <div class="item-price">${item.price} ₽</div>
          </div>
          <div class="controls">
            <button onclick="changeQty('${item.id}', -1)">−</button>
            <span id="qty-${item.id}">0</span>
            <button onclick="changeQty('${item.id}', 1)">+</button>
          </div>
        </div>
      `;
    });
  });
}

function changeQty(id, delta) {
  const item = cart[id];
  item.qty = Math.max(0, item.qty + delta);

  document.getElementById(`qty-${id}`).innerText = item.qty;
  recalc();
}

function recalc() {
  total = 0;
  Object.values(cart).forEach(i => {
    total += i.price * i.qty;
  });

  document.getElementById("orderBtn").innerText =
    total ? `Оформить заказ • ${total} ₽` : "Оформить заказ • 0 ₽";
}

function submitOrder() {
  const items = Object.values(cart).filter(i => i.qty > 0);

  if (!items.length) {
    tg.showAlert("Добавьте товары в заказ");
    return;
  }

  tg.sendData(JSON.stringify({
    type: orderType.value,
    time: orderTime.value,
    items
  }));
}
