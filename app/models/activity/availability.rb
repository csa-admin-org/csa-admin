# frozen_string_literal: true

module Activity::Availability
  extend ActiveSupport::Concern

  included do
    scope :without_participations, -> {
      includes(:participations).where(participations: { id: nil })
    }
  end

  class_methods do
    def available_for(member)
      limit = Current.org.activity_availability_limit_in_days.days.from_now
      visible
        .where(date: limit..)
        .ordered(:asc)
        .includes(:participations)
        .reject { |hd| hd.participant?(member) }
    end

    def available
      limit = Current.org.activity_availability_limit_in_days.days.from_now
      visible
        .where(date: limit..)
        .ordered(:asc)
        .includes(:participations)
        .reject(&:full?)
    end
  end

  def full?
    participants_limit && missing_participants_count.zero?
  end

  def missing_participants?
    !participants_limit || missing_participants_count.positive?
  end

  def participant?(member)
    participations.map(&:member_id).include?(member.id)
  end

  def participants_count
    participations.map(&:participants_count).sum
  end

  def missing_participants_count
    participants_limit && participants_limit - participants_count
  end
end
