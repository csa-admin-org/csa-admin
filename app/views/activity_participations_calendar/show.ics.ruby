require "tod/core_extensions"
tzid = "Zurich"

cal = Icalendar::Calendar.new
cal.timezone do |t|
  @activity_participations.each do |participation|
    activity = participation.activity
    cal.event do |e|
      e.dtstart = Icalendar::Values::DateTime.new(activity.date.at(activity.start_time), "tzid" => tzid)
      e.dtend   = Icalendar::Values::DateTime.new(activity.date.at(activity.end_time), "tzid" => tzid)
      e.summary = activity_participation_summary(participation)
    end
  end
end

cal.publish
cal.to_ical
