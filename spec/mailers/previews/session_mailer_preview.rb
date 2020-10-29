class SessionMailerPreview < ActionMailer::Preview
  def new_member_session_email
    session = Session.new(
      member: Member.new(language: I18n.locale),
      email: 'example@acp-admin.ch')
    SessionMailer.with(
      session: session,
      session_url: 'https://example.com',
    ).new_member_session_email
  end

  def new_admin_session_email
    session = Session.new(
      admin: Admin.new(language: I18n.locale),
      email: 'example@acp-admin.ch')
    SessionMailer.with(
      session: session,
      session_url: 'https://example.com',
    ).new_admin_session_email
  end
end
