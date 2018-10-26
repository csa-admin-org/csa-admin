require 'tod/core_extensions'
tzid = 'Zurich'

cal = Icalendar::Calendar.new
cal.timezone do |t|
  @halfday_participations.each do |participation|
    halfday = participation.halfday
    cal.event do |e|
      e.dtstart = Icalendar::Values::DateTime.new(halfday.date.at(halfday.start_time), 'tzid' => tzid)
      e.dtend   = Icalendar::Values::DateTime.new(halfday.date.at(halfday.end_time), 'tzid' => tzid)
      e.summary = halfday_participation_summary(participation)
    end
  end
end

cal.publish
cal.to_ical
