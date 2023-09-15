class Liquid::AdminActivityParticipationDrop < Liquid::Drop
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
    @activity_participation.carpooling_phone.present?
  end

  def carpooling_phone
    @activity_participation.carpooling_phone&.phony_formatted(normalize: Current.acp.country_code, format: :international)
  end

  def carpooling_city
    @activity_participation.carpooling_city
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .activity_participations_url(scope: :future, q: { member_id_eq: @activity_participation.member_id }, host: Current.acp.email_default_host)
  end
end
