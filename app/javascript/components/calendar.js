import { live, checked, prop, hide, show, addClass, removeClass } from 'components/utils';
import flatpickr from 'flatpickr';
import { French } from 'flatpickr/dist/l10n/fr';
import { German } from 'flatpickr/dist/l10n/de';
import 'flatpickr/dist/themes/confetti';
import 'scss/flatpickr';

const participantCountInput = '#halfday_participation_participants_count';
const carpoolingCheckbox = ".carpooling input[type='checkbox']";
const carpoolingCheckboxLabel = '.pretty_check_boxes label.carpooling';
const carpoolingPhoneInput = '#halfday_participation_carpooling_phone';
const carpoolingCityInput = '#halfday_participation_carpooling_city';

const handleDateInput = () => {
  const inputs = document.querySelectorAll('input.date-input');
  for (const el of inputs) {
    flatpickr(el, {
      locale: flatpickrLocale(),
      minDate: el.getAttribute('min'),
      maxDate: el.getAttribute('max')
    });
  }
};

const flatpickrLocale = () => {
  const locale = document.getElementById('body').getAttribute('data-locale');
  return locale === 'fr' ? French : German;
};

const selectDate = dateText => {
  hide('.halfdays label');
  checked('.halfdays input', false);
  show(`label.halfday-${dateText}`);
  const firstEnabled = document.querySelector(`label.halfday-${dateText} input:enabled`);
  if (firstEnabled) {
    firstEnabled.checked = true;
    enableForm();
  } else {
    disableForm();
  }
};

const enableForm = () => {
  hide('.no_halfdays');
  prop(participantCountInput, 'disabled', false);
  prop(carpoolingCheckbox, 'disabled', false);
  removeClass(carpoolingCheckboxLabel, 'disabled');
  handleCarpoolingChange();
  prop('#subscribe-button', 'disabled', false);
};

const disableForm = () => {
  show('.no_halfdays');
  prop(participantCountInput, 'disabled', true);
  prop(carpoolingCheckbox, 'disabled', true);
  addClass(carpoolingCheckboxLabel, 'disabled');
  prop(carpoolingPhoneInput, 'disabled', true);
  prop(carpoolingCityInput, 'disabled', true);
  prop('#subscribe-button', 'disabled', true);
};

const changeMonthYear = (dates, calendar) => {
  const currentMonthStr = String('00' + (calendar.currentMonth + 1)).slice(-2);
  const yearMonth = `${calendar.currentYear}-${currentMonthStr}`;
  const date = dates.filter(d => d.startsWith(yearMonth))[0];
  if (date) {
    calendar.setDate(date);
    selectDate(date);
  } else {
    selectDate('none');
  }
};

const prepareInlineCalendar = () => {
  const calendar = document.getElementById('calendar');
  if (!calendar) return;

  const dates = calendar.getAttribute('data-dates').split(',');
  const defaultDate = calendar.getAttribute('selected-date') || dates[0];

  selectDate(defaultDate);
  flatpickr(calendar, {
    locale: flatpickrLocale(),
    defaultDate: defaultDate,
    minDate: dates[0],
    maxDate: dates[dates.length - 1],
    enable: dates,
    inline: true,
    onChange: (selectedDates, dateStr, instance) => {
      selectDate(dateStr);
    },
    onMonthChange: (selectedDates, dateStr, instance) => {
      changeMonthYear(dates, instance);
    },
    onYearChange: (selectedDates, dateStr, instance) => {
      changeMonthYear(dates, instance);
    }
  });
};

const handleCarpoolingChange = () => {
  if (document.querySelector(carpoolingCheckbox).checked) {
    prop(carpoolingPhoneInput, 'disabled', false);
    prop(carpoolingCityInput, 'disabled', false);
  } else {
    prop(carpoolingPhoneInput, 'disabled', true);
    prop(carpoolingCityInput, 'disabled', true);
  }
};

document.addEventListener('turbolinks:load', () => {
  handleDateInput();
  prepareInlineCalendar();
  live(carpoolingCheckbox, 'change', event => {
    handleCarpoolingChange();
  });
});
