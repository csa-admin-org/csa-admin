# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

//= require jquery
//= require jquery-ui
//= require moment

class @ParticipantsCount
  constructor: (count) -> @count = count
  am: -> @count[0]
  pm: -> @count[1]
  total: -> @am() + @pm()
  title: ->
    t = []
    if typeof @am() is 'number'
      t.push "matin: #{@am()} participant(es)"
    if @am() == 'full'
      t.push "matin: complet!"
    if typeof @pm() is 'number'
      t.push "après-midi: #{@pm()} participant(es)"
    if @pm() == 'full'
      t.push "après-midi: complet!"
    t.join('\n')
  class: ->
    max = 10
    c = []
    if @am() != null && @pm() != null
      if @am() == 'full' || @pm() == 'full'
        c.push "participants-full"
      else
        c.push "participants-#{Math.min(@total(), max)}"
      c.push "ampm"
    else if @am() != null && @pm() == null
      if typeof @am() is 'number'
        c.push "participants-#{Math.min(@am() * 2, max)}"
      if @am() == 'full'
        c.push "participants-full"
      c.push "am"
    else if @am() == null && @pm() != null
      if typeof @pm() is 'number'
        c.push "participants-#{Math.min(@pm() * 2, max)}"
      if @pm() == 'full'
        c.push "participants-full"
      c.push "pm"
    c.join(" ")

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
  minDate = $('#datepicker').data('min-date')
  maxDate = $('#datepicker').data('max-date')

  $('#datepicker').datepicker
    firstDay: 1
    minDate: minDate
    maxDate: maxDate
    defaultDate: $('#halfday_work_date').val()
    onSelect: (dateText, inst) ->
      $('#halfday_work_date').val dateText
      count = datesWithParticipantsCount[dateText]
      day = moment(dateText)
      $('label.label-error').hide()
      if day.day() == 3 # Wednesday
        $('#halfday_work_period_am_label span.neuchatel').show()
        $('#halfday_work_period_am_label span.thielle').hide()
      else
        $('#halfday_work_period_am_label span.neuchatel').hide()
        $('#halfday_work_period_am_label span.thielle').show()

      $('#halfday_work_period_am').prop('disabled', false).prop('checked', false)
      $('#halfday_work_period_am_label').removeClass('disabled full')
      $('#halfday_work_period_pm').prop('disabled', false).prop('checked', false)
      $('#halfday_work_period_pm_label').removeClass('disabled full')
      if count[0] == null
        $('#halfday_work_period_am').prop('disabled', true)
        $('#halfday_work_period_am_label').addClass('disabled')
      if count[0] == 'full'
        $('#halfday_work_period_am').prop('disabled', true)
        $('#halfday_work_period_am_label').addClass('full')
      if count[1] == null
        $('#halfday_work_period_pm').prop('disabled', true)
        $('#halfday_work_period_pm_label').addClass('disabled')
      if count[1] == 'full'
        $('#halfday_work_period_pm').prop('disabled', true)
        $('#halfday_work_period_pm_label').addClass('full')
    beforeShowDay: (date) ->
      dateText = $.datepicker.formatDate('yy-mm-dd', date)
      if count = datesWithParticipantsCount[dateText]
        count = new ParticipantsCount(count)
        [true, count.class(), count.title()]
      else
        [false, null, null]
