# frozen_string_literal: true

module ActivityParticipationsHelper
  def create_activity_participation(attributes = {})
    attributes[:member] ||= create_member
    attributes[:activity] ||= create_activity

    ActivityParticipation.create!({}.merge(attributes))
  end
end
