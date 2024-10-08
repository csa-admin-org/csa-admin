# frozen_string_literal: true

class Liquid::ActivityParticipationDrop < Liquid::Drop
  def initialize(activity_participation)
    @activity_participation = activity_participation
  end

  def activity
    Liquid::ActivityDrop.new(@activity_participation.activity)
  end

  def participants_count
    @activity_participation.participants_count
  end

  def note
    @activity_participation.note.presence
  end

  def carpooling
    carpooling_participations.map { |p|
      {
        "member_name" => p.member.name,
        "member_phone" => p.carpooling_phone,
        "leaving_from_city" => p.carpooling_city
      }
    }
  end

  private

  def carpooling_participations
    if @activity_participation.respond_to?(:carpooling_participations)
      @activity_participation.carpooling_participations
    else
      ActivityParticipation
        .where(activity_id: @activity_participation.activity_id)
        .where.not(member_id: @activity_participation.member_id)
        .carpooling
        .includes(:member)
    end
  end
end
