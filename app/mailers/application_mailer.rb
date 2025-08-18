# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  helper :application, :organizations
  default from: -> { Current.org.email_default_from_address }
  layout "mailer"

  rescue_from Postmark::InactiveRecipientError do
    Scheduled::PostmarkSyncSuppressionsJob.perform_later
  end

  attr_reader :content

  after_action :set_postmark_server_token

  private

  def default_url_options
    { host: Current.org.members_url }
  end

  def content_mail(content, **args)
    args[:template_name] = "content"
    args[:template_path] = "mailers"
    @subject = args[:subject]
    @content = content
    mail(**args)
  end

  def set_postmark_server_token
    mail.delivery_method.settings[:api_token] = Current.org.postmark_server_token
  end

  def liquid_template
    mailer_method = caller_locations(1, 1)[0].label.gsub("block in ", "").split("#").last
    name = [ mailer_method, I18n.locale, "liquid" ].join(".")
    path = Rails.root.join("app/views", self.class.name.underscore, name)
    Liquid::Template.parse(File.read(path))
  end
end
