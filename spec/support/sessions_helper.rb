module SessionsHelper
  def login(owner)
    session =
      case owner
      when Member then create(:session, member_email: owner.emails_array.first)
      when Admin then create(:session, admin_email: owner.email)
      end
    visit "/sessions/#{session.token}"
  end

  def delete_session(owner)
    owner.reload.sessions.each(&:delete)
  end
end

RSpec.configure do |config|
  config.include(SessionsHelper)
end
