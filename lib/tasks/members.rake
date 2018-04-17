namespace :members do
  desc 'Send welcome emails to new active members'
  task send_welcome_emails: :environment do
    ACP.enter!('ragedevert')
    Member
      .active
      .where(welcome_email_sent_at: nil)
      .find_each(&:send_welcome_email)
    p "#{Current.acp.name}: Welcome emails send to new active members."
  end

  desc 'Ensure that members state are up to date'
  task update_state: :environment do
    ACP.enter_each! do
      Member.all.each(&:update_state!)
      p "#{Current.acp.name}: Members state updated."
    end
  end
end
