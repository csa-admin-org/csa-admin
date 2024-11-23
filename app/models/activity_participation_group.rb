# frozen_string_literal: true

class ActivityParticipationGroup
  class ActivityGroup < SimpleDelegator
    attr_accessor :period, :start_time, :end_time
  end

  def self.group(participations)
    participations
      .group_by { |p| signature(p) }
      .map { |_sign, parts| new(parts) }
  end

  def self.signature(participation)
    activity = participation.activity
    [
      participation.member_id,
      participation.participants_count,
      activity.date,
      activity.titles,
      activity.places,
      activity.place_urls,
      activity.descriptions
    ].map(&:to_s).join(":")
  end

  delegate \
    :member, :member_id,
    :participants_count,
    :note, :note?,
    :carpooling_phone, :carpooling_city,
    :carpooling_participations,
    :session,
    to: :participation

  def initialize(participations)
    @participations = participations.sort_by { |p| p.activity.start_time }
  end

  def ids
    @participations.map(&:id)
  end

  def touch(*args)
    @participations.each { |p| p.touch(*args) }
  end

  # Used for activity_participations_with_carpooling
  def activity_id
    [ activities.first.id, activities.last.id ].uniq
  end

  def activity
    @activity = ActivityGroup.new(activities.first)
    @activity.period = period
    @activity.start_time = activities.first.start_time
    @activity.end_time = activities.last.end_time
    @activity
  end

  def validated?
    @activities_validated ||= @participations.all?(&:validated?)
  end

  def rejected?
    @activities_rejected ||= @participations.all?(&:rejected?)
  end

  private

  def activities
    @activities ||= @participations.map(&:activity).sort_by(&:start_time)
  end

  def period
    activities.each_with_object([]) { |activity, periods|
      if periods.last == activity.start_time
        periods.pop
      else
        periods << activity.start_time
      end
      periods << activity.end_time
    }.each_slice(2).to_a.map { |period|
      period.map { |t| t.strftime("%-k:%M") }.join("-")
    }.join(", ")
  end

  # Used for delegation
  def participation
    @participations.first
  end
end
