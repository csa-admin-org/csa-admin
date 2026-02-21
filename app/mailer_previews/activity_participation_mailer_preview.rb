# frozen_string_literal: true

require "ostruct"

class ActivityParticipationMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def reminder_email
    params.merge!(reminder_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :activity_participation_reminder)
    ActivityParticipationMailer.with(params).reminder_email
  end

  def validated_email
    params.merge!(validated_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :activity_participation_validated)
    ActivityParticipationMailer.with(params).validated_email
  end

  def rejected_email
    params.merge!(rejected_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :activity_participation_rejected)
    ActivityParticipationMailer.with(params).rejected_email
  end

  private

  def reminder_email_params = participation_params
  def validated_email_params = participation_params
  def rejected_email_params = participation_params

  def participation_params
    {
      activity_participation: activity_participation,
      member: member,
      activity: activity
    }
  end

  def activity
    activity_preset = ActivityPreset.all.sample(random: random)
    activity = Activity.last(10).sample(random: random)

    OpenStruct.new(
      title: activity_preset&.title || "Aide aux champs",
      date: Date.current,
      period: activity&.period || "8:00-12:00",
      description: nil,
      place: activity_preset&.title || "Neuchâtel",
      place_url: activity_preset&.place_url || "https://google.map/foo",
      participants_limit: 10,
      participants_count: 4,
      missing_participants_count: 6)
  end

  def activity_participation
    OpenStruct.new(
      activity_id: 1,
      member_id: 1,
      member: member,
      activity: activity,
      participants_count: 2,
      carpooling_participations: [
        carpooling("Joe", "077 231 123 43", nil),
        carpooling("Eva", "076 131 123 41", "La Chaux-de-Fonds")
      ])
  end

  def carpooling(name, phone, city)
    OpenStruct.new(
      member: OpenStruct.new(name: name),
      carpooling_phone: phone,
      carpooling_city: city)
  end
end
