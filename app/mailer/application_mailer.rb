class ApplicationMailer < ActionMailer::Base
  default from: %{"ACP Admin" <acp-admin@thibaud.gg>}

  private

  def default_url_options
    { host: Current.acp.email_default_host }
  end
end
