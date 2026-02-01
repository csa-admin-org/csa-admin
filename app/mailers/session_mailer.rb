# frozen_string_literal: true

class SessionMailer < ApplicationMailer
  def new_member_session_email
    session = params[:session]
    I18n.with_locale(session.member.language) do
      content = liquid_template.render(
        "session_url" => params[:session_url])
      content_mail(content,
        to: session.email,
        subject: t(".subject"),
        tag: "session-member")
    end
  end

  def new_admin_session_email
    session = params[:session]
    I18n.with_locale(session.admin.language) do
      content = liquid_template.render(
        "session_url" => params[:session_url])
      content_mail(content,
        to: session.email,
        subject: t(".subject"),
        tag: "session-admin")
    end
  end

  def deletion_confirmation_email
    session = params[:session]
    I18n.with_locale(session.member.language) do
      content = liquid_template.render(
        "code" => session.deletion_code)
      content_mail(content,
        to: session.email,
        subject: t(".subject"),
        tag: "deletion-confirmation")
    end
  end
end
