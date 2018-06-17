//= require active_admin/base
//= require activeadmin/medium_editor/medium_editor
//= require activeadmin/medium_editor_input
//= require jquery-ui/i18n/datepicker-fr-CH
//= require jquery-ui/i18n/datepicker-de

$(function() {
  var locale = $('body').data('locale');
  if (locale === 'fr') {
    $.datepicker.setDefaults($.datepicker.regional['fr-CH']);
  } else {
    $.datepicker.setDefaults($.datepicker.regional[locale]);
  }

  $('#halfday_preset_id').on('change', function() {
    if (this.value === '0') {
      $('input.js-preset').prop('disabled', false);
      $('input.js-preset').prop('value', '');
    } else {
      $('input.js-preset').prop('disabled', true);
      $('input.js-preset').prop('value', 'preset');
    }
  });

  $('#basket_content_basket_sizes_small, #basket_content_basket_sizes_big').on(
    'change',
    function() {
      var bigBasketChecked, sameBasketQuantityCheckbox, smallBasketChecked;
      sameBasketQuantityCheckbox = $('#basket_content_same_basket_quantities');
      sameBasketQuantityCheckbox.prop('checked', false);
      smallBasketChecked = $('#basket_content_basket_sizes_small').prop(
        'checked'
      );
      bigBasketChecked = $('#basket_content_basket_sizes_big').prop('checked');
      if (!smallBasketChecked || !bigBasketChecked) {
        sameBasketQuantityCheckbox.prop('disabled', true);
      }
      if (smallBasketChecked && bigBasketChecked) {
        return sameBasketQuantityCheckbox.prop('disabled', false);
      }
    }
  );

  $('.js-reset_price').on('change', function() {
    var nextInput = $(':input:eq(' + ($(':input').index(this) + 1) + ')');
    nextInput.prop('value', '');
  });
});
