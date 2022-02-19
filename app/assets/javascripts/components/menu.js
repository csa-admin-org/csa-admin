$(document).on('turbolinks:load', function() {
  var ul = document.querySelector('#other ul.menu');
  if(ul) {
    Array.from(ul.getElementsByTagName('li'))
      .sort((a, b) => a.textContent.localeCompare(b.textContent))
      .forEach(li => ul.appendChild(li));
  }
});
