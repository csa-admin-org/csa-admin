# frozen_string_literal: true

class Liquid::AdminAbsenceDrop < Liquid::AbsenceDrop
  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .absence_url(@absence, {}, host: Current.org.admin_url)
  end
end
