class NewsletterMailer < ApplicationMailer
  include Templatable
  EmailRender = Struct.new(:subject, :content)

  def newsletter_email
    template_mail(params[:member],
      to: params[:to],
      stream: 'broadcast',
      **prepared_data)
  end

  # Only used by Newsletter::Delivery to persist the rendered email
  def render_newsletter_email
    render_template(params[:member], **prepared_data) do |subject, content|
      EmailRender.new(subject, content)
    end
  end

  private

  def prepared_data
    member = params[:member]
    today = I18n.with_locale(member.language) do
      params[:today] || I18n.l(Date.today)
    end
    if contents = params.delete(:template_contents)
      params[:template] = Newsletter::Template.new(contents: contents, no_preview: true)
    end
    if params[:to]
      @unsubscribe_token = Newsletter::Audience.encrypt_email(params[:to])
    end
    {
      'today' => today,
      'subject' => params[:subject],
      'member' => Liquid::MemberDrop.new(member, email: params[:to])
    }
  end
end
