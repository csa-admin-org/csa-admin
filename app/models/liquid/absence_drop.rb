# frozen_string_literal: true

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

  def note
    @absence.note.presence
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .absence_url(@absence, {}, host: Current.org.admin_url)
  end
end
