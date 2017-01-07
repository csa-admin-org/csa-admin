tzid = 'Zurich'

cal = Icalendar::Calendar.new
cal.timezone do |t|
  @halfday_participations.each do |participation|
    cal.event do |e|
      e.dtstart = Icalendar::Values::DateTime.new(participation.halfday.start_at, 'tzid' => tzid)
      e.dtend   = Icalendar::Values::DateTime.new(participation.halfday.end_at, 'tzid' => tzid)
      e.summary = halfday_participation_summary(participation)
    end
  end
end

cal.publish
cal.to_ical
