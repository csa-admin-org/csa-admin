import 'jquery-ui/ui/i18n/datepicker-fr-CH';
import 'jquery-ui/ui/i18n/datepicker-de';

$(document).on('turbolinks:load', function() {
  var locale = document.documentElement.lang
  if (locale === 'fr') {
    $.datepicker.setDefaults($.datepicker.regional['fr-CH']);
  } else {
    $.datepicker.setDefaults($.datepicker.regional[locale]);
  }
});
