# frozen_string_literal: true

require "tod/core_extensions"
require "icalendar"
require "icalendar/tzinfo"

cal = Icalendar::Calendar.new

cal.ip_name = "Flux NAME"
cal.x_wr_calname = "Flux NAME"
cal.description = "The description"
cal.url = activity_participations_url
cal.image = org_logo_url
cal.refresh_interval = "P1D"

last_modified = @activity_participations.maximum(:updated_at) || Time.current
tzid = Time.zone.tzinfo.name
tz = TZInfo::Timezone.get(tzid)
timezone = tz.ical_timezone(last_modified)
cal.add_timezone timezone
cal.last_modified = last_modified

@activity_participations.each do |participation|
  activity = participation.activity
  cal.event do |e|
    e.dtstart = Icalendar::Values::DateTime.new(activity.date.at(activity.start_time), tzid: tzid)
    e.dtend   = Icalendar::Values::DateTime.new(activity.date.at(activity.end_time), tzid: tzid)
    e.summary = activity_participation_admin_calendar_summary(participation)
  end
end

cal.publish
cal.to_ical
