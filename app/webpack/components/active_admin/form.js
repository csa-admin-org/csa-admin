$(document).on('turbolinks:load', function() {
  $('#activity_preset_id').on('change', function() {
    if (this.value === '0') {
      $('input.js-preset').prop('disabled', false);
      $('input.js-preset').prop('value', '');
    } else {
      $('input.js-preset').prop('disabled', true);
      $('input.js-preset').prop('value', 'preset');
    }
  });

  $('.js-reset_price').on('change', function() {
    var nextInput = $(':input:eq(' + ($(':input').index(this) + 1) + ')');
    nextInput.prop('value', '');
  });
});
