# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

//= require jquery
//= require jquery_ujs
//= require jquery-ui

$.datepicker.regional["fr"] =
  clearText: "Effacer"
  clearStatus: ""
  closeText: "Fermer"
  closeStatus: "Fermer sans modifier"
  prevText: "<Préc"
  prevStatus: "Voir le mois précédent"
  nextText: "Suiv>"
  nextStatus: "Voir le mois suivant"
  currentText: "Courant"
  currentStatus: "Voir le mois courant"
  monthNames: [
    "Janvier"
    "Février"
    "Mars"
    "Avril"
    "Mai"
    "Juin"
    "Juillet"
    "Août"
    "Septembre"
    "Octobre"
    "Novembre"
    "Décembre"
  ]
  monthNamesShort: [
    "Jan"
    "Fév"
    "Mar"
    "Avr"
    "Mai"
    "Jun"
    "Jul"
    "Aoû"
    "Sep"
    "Oct"
    "Nov"
    "Déc"
  ]
  monthStatus: "Voir un autre mois"
  yearStatus: "Voir un autre année"
  weekHeader: "Sm"
  weekStatus: ""
  dayNames: [
    "Dimanche"
    "Lundi"
    "Mardi"
    "Mercredi"
    "Jeudi"
    "Vendredi"
    "Samedi"
  ]
  dayNamesShort: [
    "Dim"
    "Lun"
    "Mar"
    "Mer"
    "Jeu"
    "Ven"
    "Sam"
  ]
  dayNamesMin: [
    "Di"
    "Lu"
    "Ma"
    "Me"
    "Je"
    "Ve"
    "Sa"
  ]
  dayStatus: "Utiliser DD comme premier jour de la semaine"
  dateStatus: "Choisir le DD, MM d"
  dateFormat: 'yy-mm-dd'
  firstDay: 0
  initStatus: "Choisir la date"
  isRTL: false

$.datepicker.setDefaults $.datepicker.regional["fr"]

selectDate = (dateText) ->
  $('.no_halfdays').hide()
  $('.halfdays label').hide()
  $('#subscribe-button').prop('disabled', false)
  $('.halfdays input').prop('checked', false)
  $("label.halfday-#{dateText}").show()
  $("label.halfday-#{dateText} input:enabled:first").prop('checked', true);
  unless $("label.halfday-#{dateText} input:enabled").length
    $('#subscribe-button').prop('disabled', true)

$ ->
  dateTexts = $('#datepicker').data('dates')
  if dateTexts
    [minDateText, ..., maxDateText] = dateTexts
    selectedDateText = $('#datepicker').data('selected-date') or minDateText
    selectDate(selectedDateText)

    $('#datepicker').datepicker
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

