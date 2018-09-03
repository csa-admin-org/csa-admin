# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

//= require jquery
//= require jquery_ujs
//= require jquery-ui
//= require jquery-ui/i18n/datepicker-fr-CH
//= require jquery-ui/i18n/datepicker-de
//= require forms
//= require turbolinks

selectDate = (dateText) ->
  $('.no_halfdays').hide()
  $('.halfdays label').hide()
  $('#subscribe-button').prop('disabled', false)
  $('.halfdays input').prop('checked', false)
  $("label.halfday-#{dateText}").show()
  $("label.halfday-#{dateText} input:enabled:first").prop('checked', true);
  unless $("label.halfday-#{dateText} input:enabled").length
    $('#subscribe-button').prop('disabled', true)

datepickerFallback = ->
  @dateFields = $('input.date-input')
  return if @dateFields.length == 0 || @dateFields[0].type is 'date'
  @dateFields.datepicker
    dateFormat: 'yy-mm-dd',
    minDate: @dateFields.attr('min'),
    maxDate: @dateFields.attr('max')

setDatepickerLocale = ->
  locale = $('body').data('locale')
  if locale == 'fr'
    $.datepicker.setDefaults $.datepicker.regional['fr-CH']
  else
    $.datepicker.setDefaults $.datepicker.regional[locale]

setupDatepicker = ->
  setDatepickerLocale()
  dateTexts = $('#datepicker').data('dates')
  if dateTexts
    [minDateText, ..., maxDateText] = dateTexts
    selectedDateText = $('#datepicker').data('selected-date') or minDateText
    selectDate(selectedDateText)

    $('#datepicker').datepicker
      dateFormat: 'yy-mm-dd',
      firstDay: 1
      minDate: minDateText
      maxDate: maxDateText
      defaultDate: selectedDateText
      onSelect: (dateText, inst) ->
        selectDate(dateText)
      beforeShowDay: (date) ->
        dateText = $.datepicker.formatDate('yy-mm-dd', date)
        if dateText in dateTexts
          [true, 'available', null]
        else
          [false, null, null]
      onChangeMonthYear: (year, month) ->
        dateText = (dateTexts.filter (d) ->
          dd = new Date(d)
          dd.getFullYear() is year and dd.getMonth() + 1 is month
        )[0]
        if dateText
          $('#datepicker').datepicker('setDate', dateText)
          selectDate(dateText)
        else
          $('.no_halfdays').show()
          $('.halfdays label').hide()
          $('#subscribe-button').prop('disabled', true)
          $('.halfdays input').prop('checked', false)


$ ->
  document.addEventListener "turbolinks:load", ->
    setupDatepicker()
    datepickerFallback()


