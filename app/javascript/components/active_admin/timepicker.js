import 'jquery-timepicker/jquery.timepicker';

$(function() {
  $('input[type="time"]').timepicker({
    timeFormat: 'HH:mm',
    interval: 15,
    minTime: '6:00',
    maxTime: '23:30',
    dynamic: false,
    dropdown: true,
    scrollbar: true
  });
});
