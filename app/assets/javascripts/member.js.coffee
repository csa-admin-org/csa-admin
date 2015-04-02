# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

//= require jquery
//= require jquery-ui

class @ParticipantsCount
  constructor: (count) -> @count = count
  am: -> @count[0]
  pm: -> @count[1]
  total: -> @am() + @pm()
  title: -> "matin: #{@am()} participant(es)\naprès-midi: #{@pm()} participant(es)"
  class: ->
    max = 10
    if @total() <= max
      "participants-#{@total()}"
    else
      "participants-#{max}"


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

$ ->
  datesWithParticipantsCount = $('#datepicker').data('dates-with-participants-count')
  today = new Date()
  lastDate = new Date(today.getFullYear(), 11, 31)

  $('#datepicker').datepicker
    firstDay: 1
    minDate: today
    maxDate: lastDate
    defaultDate: $('#halfday_work_date').val()
    onSelect: (dateText, inst) ->
      $('#halfday_work_date').val dateText
    beforeShowDay: (date) ->
      date = $.datepicker.formatDate('yy-mm-dd', date)
      if count = datesWithParticipantsCount[date]
        count = new ParticipantsCount(count)
        [true, count.class(), count.title()]
      else
        [false, null, null]
