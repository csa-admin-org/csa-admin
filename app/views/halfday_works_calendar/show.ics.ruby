cal = Icalendar::Calendar.new

@halfday_works.each do |halfday_work|
  cal.event do |e|
    e.dtstart = halfday_work.date + 8.hours
    e.dtend   = halfday_work.date + 12.hours
    e.summary = halfday_work_summary(halfday_work)
  end if halfday_work.period_am
  cal.event do |e|
    e.dtstart = halfday_work.date + 13.hours + 30.minutes
    e.dtend   = halfday_work.date + 17.hours + 30.minutes
    e.summary = halfday_work_summary(halfday_work)
  end if halfday_work.period_pm
end

cal.publish
cal.to_ical
