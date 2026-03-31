# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  helper :application, :organizations
  default from: -> { default_from }

  layout "mailer"

  attr_reader :content

  after_action :set_postmark_server_token

  private

  def default_from
    if Tenant.demo?
      email_address_with_name(ENV["ULTRA_ADMIN_EMAIL"], "CSA Admin")
    else
      email_address_with_name(
        Current.org.email_default_from,
        Current.org.name)
    end
  end

  def default_url_options
    { host: mailer_host }
  end

  def mailer_host
    host = Tenant.members_host
    if Rails.env.local?
      # Transform production TLD to .test for local development
      # e.g., "membres.ragedevert.ch" -> "membres.ragedevert.test"
      parsed = PublicSuffix.parse(host)
      host = "#{parsed.trd}.#{parsed.sld}.test"
    end
    "https://#{host}"
  end

  def content_mail(content, **args)
    args[:template_name] = "content"
    args[:template_path] = "mailers"
    @subject = args[:subject]
    @content = sanitize_action_text_for_email(content)
    mail(**args)
  end

  def sanitize_action_text_for_email(content)
    content
      .gsub(/<action-text-attachment\b[^>]*>/i, "")
      .gsub(%r{</action-text-attachment>}i, "")
  end

  def set_postmark_server_token
    mail.delivery_method.settings[:api_token] = Current.org.postmark_server_token
  end

  def liquid_template
    mailer_method = caller_locations(1, 1)[0].label.gsub("block in ", "").split("#").last
    mailer_dir = self.class.name.underscore
    content = LiquidErb.render("#{mailer_dir}/#{mailer_method}", locale: I18n.locale)
    Liquid::Template.parse(content)
  end
end
