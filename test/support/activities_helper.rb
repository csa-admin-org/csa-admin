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

  def insert_admin_form_activities!(dates)
    now = Time.current
    Activity.insert_all(dates.map { |date|
      {
        date: date,
        start_time: "08:00",
        end_time: "10:00",
        places: { "en" => "Farm" },
        titles: { "en" => "Extra" },
        descriptions: {},
        place_urls: {},
        visible: true,
        created_at: now,
        updated_at: now
      }
    })
    Activity.where(date: dates).order(:date)
  end

  def insert_activity_participations!(activities, member: members(:john))
    now = Time.current
    ActivityParticipation.insert_all(activities.map { |activity|
      {
        activity_id: activity.id,
        member_id: member.id,
        participants_count: 1,
        state: "pending",
        created_at: now,
        updated_at: now
      }
    })
  end
end
