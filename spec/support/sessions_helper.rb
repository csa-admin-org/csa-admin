module SessionsHelper
  def login(member)
    session = create(:session, member: member)
    visit "/sessions/#{session.token}"
  end

  def delete_session(member)
    member.sessions.delete_all
  end
end

RSpec.configure do |config|
  config.include(SessionsHelper)
end
