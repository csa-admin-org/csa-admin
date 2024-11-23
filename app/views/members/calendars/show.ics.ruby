# frozen_string_literal: true

require "tod/core_extensions"
require "icalendar/tzinfo"

cal = Icalendar::Calendar.new

cal.ip_name = Current.org.name
cal.x_wr_calname = Current.org.name
cal.url = Current.org.members_url
cal.image = org_logo_url
cal.refresh_interval = "P1W"

last_modified = @baskets.maximum(:updated_at) || Time.current
tzid = Time.zone.tzinfo.name
tz = TZInfo::Timezone.get(tzid)
timezone = tz.ical_timezone(last_modified)
cal.add_timezone timezone
cal.last_modified = last_modified

green = "#19A24A"
cal.color = green
cal.x_apple_calendar_color = green

@baskets.each do |basket|
  delivery = basket.delivery
  cal.event do |e|
    e.ip_class = "PRIVATE"
    e.dtstart = Icalendar::Values::Date.new(delivery.date)
    e.dtend   = Icalendar::Values::Date.new(delivery.date)
    e.summary = t(".event.summary_#{basket.state}",
      org_name: Current.org.name,
      default: t(".event.summary", org_name: Current.org.name))
    e.description = basket_calendar_description(basket)
    if basket.depot.full_address
      e.location = basket.depot.full_address
    end
    e.url = members_deliveries_url
  end
end

@activity_participations.each do |activity_participation|
  activity = activity_participation.activity
  cal.event do |e|
    e.ip_class = "PRIVATE"
    e.dtstart = Icalendar::Values::DateTime.new(activity.date.at(activity.start_time), tzid: tzid)
    e.dtend   = Icalendar::Values::DateTime.new(activity.date.at(activity.end_time), tzid: tzid)
    e.summary = "#{activity.title} (#{Current.org.name})"
    e.summary += " ✅" if activity_participation.validated?
    e.summary += " ❌" if activity_participation.rejected?
    e.description = activity_participation_admin_calendar_description(activity_participation)
    e.location = activity.place
    e.url = activity.place_url if activity.place_url?
  end
end

cal.publish
cal.to_ical
