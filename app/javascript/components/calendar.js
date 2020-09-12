import { live, checked, prop, hide, show, addClass, removeClass } from 'components/utils';
import flatpickr from 'flatpickr';
import { French } from 'flatpickr/dist/l10n/fr';
import { German } from 'flatpickr/dist/l10n/de';
import 'flatpickr/dist/themes/confetti';
import 'stylesheets/flatpickr';

const participantCountInput = '#activity_participation_participants_count';
const carpoolingCheckbox = ".carpooling input[type='checkbox']";
const carpoolingCheckboxLabel = '.pretty_check_boxes label.carpooling';
const carpoolingPhoneInput = '#activity_participation_carpooling_phone';
const carpoolingCityInput = '#activity_participation_carpooling_city';

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
  const locale = document.documentElement.lang;
  return locale === 'fr' ? French : German;
};

const initDate = dateText => {
  hide('.activities label');
  show(`label.activity-${dateText}`);
  const checked = document.querySelector(`label.activity-${dateText} input:checked`);
  if (!checked) {
    const firstEnabled = document.querySelector(`label.activity-${dateText} input:enabled`);
    firstEnabled.checked = true;
  }
  enableForm();
};

const selectDate = dateText => {
  hide('.activities label');
  checked('.activities input', false);
  show(`label.activity-${dateText}`);
  const firstEnabled = document.querySelector(`label.activity-${dateText} input:enabled`);
  if (firstEnabled) {
    firstEnabled.checked = true;
    enableForm();
  } else {
    disableForm();
  }
};

const enableForm = () => {
  hide('.no_activities');
  prop(participantCountInput, 'disabled', false);
  prop(carpoolingCheckbox, 'disabled', false);
  removeClass(carpoolingCheckboxLabel, 'disabled');
  handleCarpoolingChange();
  prop('#subscribe-button', 'disabled', false);
};

const disableForm = () => {
  show('.no_activities');
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

const formatDate = date => {
  const d = new Date(date);
  let month = '' + (d.getMonth() + 1);
  let day = '' + d.getDate();
  let year = d.getFullYear();

  if (month.length < 2) month = '0' + month;
  if (day.length < 2) day = '0' + day;

  return [year, month, day].join('-');
};

const prepareInlineCalendar = () => {
  const calendar = document.getElementById('calendar');
  if (!calendar) return;

  const dates = calendar.getAttribute('data-dates').split(',');
  const defaultDate = calendar.getAttribute('data-selected_date') || dates[0];

  initDate(defaultDate);
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
      const ddates = [formatDate(selectedDates[0])].concat(dates)
      changeMonthYear(ddates, instance);
    },
    onYearChange: (selectedDates, dateStr, instance) => {
      const ddates = [formatDate(selectedDates[0])].concat(dates)
      changeMonthYear(ddates, instance);
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
