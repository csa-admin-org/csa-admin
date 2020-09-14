import { live } from 'components/utils';


document.addEventListener('turbolinks:load', () => {
  const showMenu = () => {
    const menu = document.getElementById('menu');
    menu.setAttribute("aria-expanded", 'true');
  }
  const hideMenu = () => {
    const menu = document.getElementById('menu');
    if (menu.getAttribute("aria-expanded") == 'true') {
      menu.setAttribute("aria-expanded", 'false');
    }
  }
  hideMenu();

  live(".show_menu a", 'click', event => {
    showMenu();
    event.preventDefault();
  });

  live(".hide_menu a", 'click', event => {
    hideMenu();
    event.preventDefault();
  });
});
