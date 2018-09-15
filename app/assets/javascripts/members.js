//= require jquery
//= require jquery-ui/widgets/datepicker
//= require jquery-ui/i18n/datepicker-fr-CH
//= require jquery-ui/i18n/datepicker-de
//= require turbolinks

const selectDate = function(dateText) {
  $('.no_halfdays').hide();
  $('.halfdays label').hide();
  $('#subscribe-button').prop('disabled', false);
  $('.halfdays input').prop('checked', false);
  $(`label.halfday-${dateText}`).show();
  $(`label.halfday-${dateText} input:enabled:first`).prop('checked', true);
  if (!$(`label.halfday-${dateText} input:enabled`).length) {
    $('#subscribe-button').prop('disabled', true);
  }
};

const datepickerFallback = function() {
  this.dateFields = $('input.date-input');
  if (this.dateFields.length === 0 || this.dateFields[0].type === 'date') {
    return;
  }
  this.dateFields.datepicker({
    dateFormat: 'yy-mm-dd',
    minDate: this.dateFields.attr('min'),
    maxDate: this.dateFields.attr('max')
  });
};

const setDatepickerLocale = function() {
  const locale = $('body').data('locale');
  if (locale === 'fr') {
    $.datepicker.setDefaults($.datepicker.regional['fr-CH']);
  } else {
    $.datepicker.setDefaults($.datepicker.regional[locale]);
  }
};

const setupDatepicker = function() {
  setDatepickerLocale();
  const dateTexts = $('#datepicker').data('dates');
  if (dateTexts) {
    const minDateText = dateTexts[0],
      maxDateText = dateTexts[dateTexts.length - 1];
    const selectedDateText =
      $('#datepicker').data('selected-date') || minDateText;
    selectDate(selectedDateText);

    $('#datepicker').datepicker({
      dateFormat: 'yy-mm-dd',
      firstDay: 1,
      minDate: minDateText,
      maxDate: maxDateText,
      defaultDate: selectedDateText,
      onSelect(dateText, inst) {
        selectDate(dateText);
      },
      beforeShowDay(date) {
        const dateText = $.datepicker.formatDate('yy-mm-dd', date);
        if (dateTexts.includes(dateText)) {
          return [true, 'available', null];
        } else {
          return [false, null, null];
        }
      },
      onChangeMonthYear(year, month) {
        const dateText = dateTexts.filter(function(d) {
          const dd = new Date(d);
          return dd.getFullYear() === year && dd.getMonth() + 1 === month;
        })[0];
        if (dateText) {
          $('#datepicker').datepicker('setDate', dateText);
          selectDate(dateText);
        } else {
          $('.no_halfdays').show();
          $('.halfdays label').hide();
          $('#subscribe-button').prop('disabled', true);
          $('.halfdays input').prop('checked', false);
        }
      }
    });
  }
};

$(() =>
  document.addEventListener('turbolinks:load', function() {
    setupDatepicker();
    datepickerFallback();
  })
);
