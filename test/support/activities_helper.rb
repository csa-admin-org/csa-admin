# frozen_string_literal: true

module ActivitiesHelper
  def create_activity(attributes = {})
    activity = Activity.create!({
      place: "Farm",
      start_time: "08:00",
      end_time: "10:00",
      preset_id: activity_presets(:harvest).id
    }.merge(attributes))
    Activity.find(activity.id) # hard reload to get preset
  end
end
