tzid = 'Zurich'

cal = Icalendar::Calendar.new
cal.timezone do |t|

  @halfday_works.each do |halfday_work|
    cal.event do |e|
      e.dtstart = Icalendar::Values::DateTime.new(halfday_work.date + 8.hours, 'tzid' => tzid)
      e.dtend   = Icalendar::Values::DateTime.new(halfday_work.date + 12.hours, 'tzid' => tzid)
      e.summary = halfday_work_summary(halfday_work)
    end if halfday_work.period_am
    cal.event do |e|
      e.dtstart = Icalendar::Values::DateTime.new(halfday_work.date + 13.hours + 30.minutes, 'tzid' => tzid)
      e.dtend   = Icalendar::Values::DateTime.new(halfday_work.date + 17.hours + 30.minutes, 'tzid' => tzid)
      e.summary = halfday_work_summary(halfday_work)
    end if halfday_work.period_pm
  end
end

cal.publish
cal.to_ical
