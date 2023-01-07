class NewsletterMailer < ApplicationMailer
  include Templatable

  def newsletter_email
    member = params[:member]
    today = I18n.with_locale(member.language) do
      params[:today] || I18n.l(Date.today)
    end

    data = {
      'today' => today,
      'subject' => params[:subject],
      'member' => Liquid::MemberDrop.new(member)
    }
    template_mail(member, to: params[:to], **data)
  end
end
