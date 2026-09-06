# frozen_string_literal: true

module Demo::Seeder::Activities
  extend ActiveSupport::Concern

  private

  def seed_activities!
    log "Seeding activities..."
    @activities = []
    presets = ActivityPreset.all.to_a
    return if presets.empty?

    hour_work = Current.org.activity_i18n_scope == "hour_work"
    seed_fiscal_years.each do |fy|
      range_end = [ fy.end_of_year, Date.current - 1.day ].min
      range_start = fy.beginning_of_year + 1.month
      next if range_start > range_end

      create_activities_for_period!(
        presets: presets,
        hour_work: hour_work,
        start_date: range_start,
        count: fy.past? ? 10 : 8,
        max_date: range_end)
    end
    create_activities_for_period!(
      presets: presets,
      hour_work: hour_work,
      start_date: Date.current + 1.day,
      count: 8)
    seed_activity_participations!
  end

  def create_activities_for_period!(presets:, hour_work:, start_date:, count:, max_date: nil)
    date = skip_weekend(start_date)
    spacing = max_date && [ ((max_date - date).to_i / [ count, 1 ].max), 14 ].max
    count.times do
      break if max_date && date > max_date

      create_activity_on!(date, presets.sample, hour_work)
      date = skip_weekend(date + (spacing || rand(3..7).days))
    end
  end

  def skip_weekend(date)
    date += 1.day while date.saturday? || date.sunday?
    date
  end

  def create_activity_on!(date, preset, hour_work)
    if hour_work
      [ 9, 10, 11 ].each { |hour| save_activity!(date, preset, hour, hour + 1) }
    else
      save_activity!(date, preset, "9:00", "12:00")
    end
  end

  def save_activity!(date, preset, start_time, end_time)
    activity = Activity.new(
      date: date,
      start_time: start_time.is_a?(Integer) ? Tod::TimeOfDay.new(start_time) : Tod::TimeOfDay.parse(start_time),
      end_time: end_time.is_a?(Integer) ? Tod::TimeOfDay.new(end_time) : Tod::TimeOfDay.parse(end_time),
      titles: preset.titles,
      places: preset.places,
      place_urls: preset.place_urls,
      participants_limit: rand(4..10))
    activity.save!(validate: date >= Date.current)
    @activities << activity
  end

  def seed_activity_participations!
    log "Seeding activity participations..."
    return if @activities.blank?

    past, upcoming = @activities.partition { |activity| activity.date < Date.current }
    activities_to_fill = past + upcoming.sample([ upcoming.size / 2, 1 ].max)
    activities_to_fill.each { |activity| fill_activity_participations!(activity) }
  end

  def fill_activity_participations!(activity)
    members = members_with_demanded_participations_on(activity.date)
    return if members.empty?

    max_participants = [ activity.participants_limit || 4, members.size ].min
    participants_count = activity.date < Date.current ? [ 3, max_participants ].min : rand(1..max_participants)
    members.sample(participants_count).each do |member|
      next if ActivityParticipation.exists?(activity: activity, member: member)

      create_activity_participation!(activity, member)
    end
  end

  def create_activity_participation!(activity, member)
    participation = ActivityParticipation.new(activity: activity, member: member, participants_count: 1)
    if activity.date < Date.current
      participation.save!(validate: false)
      if rand < 0.85
        participation.update_columns(
          state: "validated",
          validated_at: activity.date + rand(1..3).days)
      end
    else
      participation.save!
    end
  end
end
