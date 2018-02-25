class ApplicationMailer < ActionMailer::Base
  helper :application
  helper :halfdays

  default \
    from: -> { Current.acp.email_default_from }
  layout 'mailer'

  def default_url_options
    { host: Current.acp.email_default_host }
  end

  def self.postmark_settings
    { api_token: Current.acp.email_api_token }
  end
end
