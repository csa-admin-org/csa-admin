# frozen_string_literal: true

module ActivitiesHelper
  def create_activity(attributes = {})
    Activity.create!({
      place: "Farm",
      start_time: "08:00",
      end_time: "10:00"
    }.merge(attributes))
  end
end
