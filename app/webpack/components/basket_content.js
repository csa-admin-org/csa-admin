$(document).on('turbolinks:load', function() {
  $('#basket_content_basket_sizes_small, #basket_content_basket_sizes_big').on(
    'change',
    function() {
      var bigBasketChecked, sameBasketQuantityLabel, sameBasketQuantityCheckbox, smallBasketChecked;
      sameBasketQuantityLabel = $('label[for="basket_content_same_basket_quantities"]');
      sameBasketQuantityCheckbox = $('#basket_content_same_basket_quantities');
      sameBasketQuantityCheckbox.prop('checked', false);
      smallBasketChecked = $('#basket_content_basket_sizes_small').prop('checked');
      bigBasketChecked = $('#basket_content_basket_sizes_big').prop('checked');
      if (!smallBasketChecked || !bigBasketChecked) {
        sameBasketQuantityCheckbox.prop('disabled', true);
        sameBasketQuantityLabel.addClass('disabled');
      }
      if (smallBasketChecked && bigBasketChecked) {
        sameBasketQuantityCheckbox.prop('disabled', false);
        sameBasketQuantityLabel.removeClass('disabled');
        return;
      }
    }
  );

  $('#basket_content_basket_sizes_small').on('change', function() {
    var smallBasketCheckbox, bigBasketCheckbox;
    smallBasketCheckbox = $('#basket_content_basket_sizes_small');
    bigBasketCheckbox = $('#basket_content_basket_sizes_big');
    if (!smallBasketCheckbox.prop('checked') && !bigBasketCheckbox.prop('checked')) {
      bigBasketCheckbox.prop('checked', true);
    }
  });

  $('#basket_content_basket_sizes_big').on('change', function() {
    var smallBasketCheckbox, bigBasketCheckbox;
    smallBasketCheckbox = $('#basket_content_basket_sizes_small');
    bigBasketCheckbox = $('#basket_content_basket_sizes_big');
    if (!smallBasketCheckbox.prop('checked') && !bigBasketCheckbox.prop('checked')) {
      smallBasketCheckbox.prop('checked', true);
    }
  });
});
