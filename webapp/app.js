const tg = window.Telegram.WebApp;
tg.expand();

let menu = [];
let cart = [];

fetch("/menu.json")
  .then(res => res.json())
  .then(data => {
    menu = data.categories;
    renderMenu();
  });

function renderMenu() {
  const container = document.getElementById("menu");
  menu.forEach(cat => {
    container.innerHTML += `<h2>${cat.name}</h2>`;
    cat.items.forEach(item => {
      container.innerHTML += `
        <div class="item">
          ${item.name} — ${item.price} ₽
          <button onclick='add("${item.id}", "${item.name}", ${item.price})'>+</button>
        </div>`;
    });
  });
}

function add(id, name, price) {
  const found = cart.find(i => i.id === id);
  if (found) found.qty++;
  else cart.push({ id, name, price, qty: 1 });
}

function submitOrder() {
  tg.sendData(JSON.stringify({
    type: document.getElementById("orderType").value,
    time: document.getElementById("orderTime").value,
    items: cart
  }));
}
