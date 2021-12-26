//= require tom-select/dist/js/tom-select.complete.js

$(document).on('turbolinks:load', function() {
  if (document.getElementById('select-tags')) {
    new TomSelect("#select-tags", {
      plugins: { remove_button: true }
    });
  }
});
