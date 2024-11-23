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
    @activity_participation.carpooling_participations.map { |p|
      {
        "member_name" => p.member.name,
        "member_phone" => p.carpooling_phone,
        "leaving_from_city" => p.carpooling_city
      }
    }
  end
end
