//= require jquery-timepicker/jquery.timepicker

$(document).on('turbolinks:load', function() {
  $('input[type="time"]').timepicker({
    timeFormat: 'H:i',
    minTime: '6:00',
    maxTime: '23:30',
  });
});
