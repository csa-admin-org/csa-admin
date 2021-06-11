class ActivityParticipationGroup
  class ActivityGroup < SimpleDelegator
    attr_accessor :period
  end

  def self.group(participations)
    participations
      .group_by { |p| signature(p) }
      .map { |_sign, parts| parts }
  end

  def self.signature(participation)
    activity = participation.activity
    participation.member_id.to_s +
      participation.participants_count.to_s +
      activity.date.to_s +
      activity.titles.to_s +
      activity.places.to_s +
      activity.place_urls.to_s +
      activity.descriptions.to_s
  end

  delegate :member, :member_id, :participants_count, to: :participation

  def initialize(participations)
    @participations = participations
  end

  # Used for activity_participations_with_carpooling
  def activity_id
    [activities.first.id, activities.last.id].uniq
  end

  def activity
    @activity = ActivityGroup.new(activities.first)
    @activity.period = period
    @activity
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
      period.map { |t| t.strftime('%-k:%M') }.join('-')
    }.join(', ')
  end

  # Used for delegation
  def participation
    @participations.first
  end
end
