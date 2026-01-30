const tg = Telegram.WebApp;
tg.expand();

let cart = [];
let menu;

fetch("/menu.json")
  .then(r => r.json())
  .then(data => {
    menu = data.categories;
    renderMenu();
  });

function renderMenu() {
  const root = document.getElementById("menu");

  menu.forEach(cat => {
    root.innerHTML += `<div class="category">${cat.name}</div>`;
    cat.items.forEach(i => {
      root.innerHTML += `
        <div class="item">
          <div>${i.name}<br><small>${i.price} ₽</small></div>
          <button onclick='add("${i.id}", "${i.name}", ${i.price})'>+</button>
        </div>
      `;
    });
  });
}

function add(id, name, price) {
  const item = cart.find(i => i.id === id);
  item ? item.qty++ : cart.push({ id, name, price, qty: 1 });
}

function submitOrder() {
  if (!cart.length) {
    tg.showAlert("Добавьте товары");
    return;
  }

  tg.sendData(JSON.stringify({
    type: orderType.value,
    time: orderTime.value,
    items: cart
  }));
}
