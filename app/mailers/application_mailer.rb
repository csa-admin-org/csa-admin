class ApplicationMailer < ActionMailer::Base
  default from: -> { Current.acp.email_default_from }
  layout 'mailer'

  after_action :set_postmark_api_token

  private

  def default_url_options
    { host: Current.acp.email_default_host }
  end

  def content_mail(content, **args)
    args[:template_name] = 'content'
    args[:template_path] = 'mailers'
    @subject = args[:subject]
    @content = content
    mail(**args)
  end

  def set_postmark_api_token
    mail.delivery_method.settings[:api_token] =
      Current.acp.credentials(:postmark, :api_token)
  end

  def liquid_template
    mailer_method = caller_locations(1,1)[0].label.gsub('block in ', '')
    name = [mailer_method, I18n.locale, 'liquid'].join('.')
    path = Rails.root.join('app/views', self.class.name.underscore, name)
    Liquid::Template.parse(File.read(path))
  end
end

Liquid::Template.register_tag('button', Liquid::ButtonBlock)
