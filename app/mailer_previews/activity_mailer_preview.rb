class ActivityMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def participation_reminder_email
    params.merge!(participation_reminder_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :activity_participation_reminder)
    ActivityMailer.with(params).participation_reminder_email
  end

  def participation_validated_email
    params.merge!(participation_reminder_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :activity_participation_validated)
    ActivityMailer.with(params).participation_validated_email
  end

  def participation_rejected_email
    params.merge!(participation_reminder_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :activity_participation_rejected)
    ActivityMailer.with(params).participation_rejected_email
  end

  private

  def participation_reminder_email_params
    {
      member: member,
      activity: activity,
      activity_participation: activity_participation
    }
  end

  def participation_validated_email_params
    {
      member: member,
      activity: activity,
      activity_participation: activity_participation
    }
  end

  def participation_rejected_email_params
    {
      member: member,
      activity: activity,
      activity_participation: activity_participation
    }
  end

  def activity
    activity_preset = ActivityPreset.all.sample(random: random)
    activity = Activity.last(10).sample(random: random)

    OpenStruct.new(
      title: activity_preset&.title || 'Aide aux champs',
      date: Date.today,
      period: activity&.period || '8:00-12:00',
      description: nil,
      place: activity_preset&.title || 'Neuchâtel',
      place_url: activity_preset&.place_url || 'https://google.map/foo')
  end

  def activity_participation
    OpenStruct.new(
      activity_id: 1,
      member_id: 1,
      member: member,
      activity: activity,
      participants_count: 2,
      carpooling_participations: [
        carpooling('Joe', '077 231 123 43', nil),
        carpooling('Eva', '076 131 123 41', 'La Chaux-de-Fonds')
      ])
  end

  def carpooling(name, phone, city)
    OpenStruct.new(
      member: OpenStruct.new(name: name),
      carpooling_phone: phone,
      carpooling_city: city)
  end
end


