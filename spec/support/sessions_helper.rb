module SessionsHelper
  def login(member, email: nil)
    session = create(:session,
      member: member,
      email: email || member.emails_array.first)
    visit "/sessions/#{session.token}"
  end

  def delete_session(member)
    member.reload.sessions.each(&:delete)
  end
end

RSpec.configure do |config|
  config.include(SessionsHelper)
end
