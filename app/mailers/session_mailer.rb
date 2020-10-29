class SessionMailer < ApplicationMailer
  def new_member_session_email
    session = params[:session]
    I18n.with_locale(session.member.language) do
      content = liquid_template.render(
        'session_url' => params[:session_url])
      content_mail(content,
        to: session.email,
        subject: t('.subject'))
    end
  end

  def new_admin_session_email
    session = params[:session]
    I18n.with_locale(session.admin.language) do
      content = liquid_template.render(
        'session_url' => params[:session_url])
      content_mail(content,
        to: session.email,
        subject: t('.subject'))
    end
  end
end
