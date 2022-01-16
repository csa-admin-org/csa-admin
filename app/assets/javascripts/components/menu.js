$(document).on('turbolinks:load', function() {
  var ul = document.querySelector('#other ul.menu');
  Array.from(ul.getElementsByTagName("LI"))
    .sort((a, b) => a.textContent.localeCompare(b.textContent))
    .forEach(li => ul.appendChild(li));
});
