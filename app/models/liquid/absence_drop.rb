class Liquid::AbsenceDrop < Liquid::Drop
  def initialize(absence)
    @absence = absence
  end

  def started_on
    I18n.l(@absence.started_on)
  end

  def ended_on
    I18n.l(@absence.ended_on)
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .absence_url(@absence, {}, host: Current.acp.email_default_host)
  end
end
