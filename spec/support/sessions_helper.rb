module SessionsHelper
  def login(member, email: nil)
    session = create(:session,
      member: member,
      email: email || member.emails_array.first)
    visit "/sessions/#{session.token}"
  end

  def delete_session(member)
    member.sessions.delete_all
  end
end

RSpec.configure do |config|
  config.include(SessionsHelper)
end
