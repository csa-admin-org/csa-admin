# frozen_string_literal: true

module SessionsHelper
  def login(owner)
    session = create_session(owner)
    visit "/sessions/#{session.token}"
  end

  def create_session(owner, attributes = {})
    session = Session.new(
      remote_addr: "127.0.0.1",
      user_agent: "a browser user agent")
    session.assign_attributes(attributes)
    case owner
    when Member
      session.member_email = owner.emails_array.first
    when Admin
      session.admin_email = owner.email
    end
    session.save!
    session
  end

  def delete_session(owner)
    owner.reload.sessions.each(&:delete)
  end
end
