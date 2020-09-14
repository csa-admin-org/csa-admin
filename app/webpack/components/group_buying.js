import { live } from 'components/utils';

const updateOrderAmount = () => {
  const items = document.querySelectorAll("#group-buying-order-form input[type='number']")
  if(items.length == 0) return;

  const amountWrapper = document.getElementById("amount-wrapper")
  const amountElement = document.getElementById("amount")
  let amount = 0.0;
  items.forEach((item, index) => {
    amount = amount + (item.value * item.dataset.price);
  })
  amountWrapper.style.display = 'flex';
  amountElement.textContent = amountElement.textContent.replace(/\d+\.\d+/, Number(amount).toFixed(2))
};

document.addEventListener('turbolinks:load', () => {
  updateOrderAmount();
  live("#group-buying-order-form input[type='number']", 'change', event => {
    updateOrderAmount();
  });
});
