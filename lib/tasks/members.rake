namespace :members do
  desc 'Send welcome emails to new active members'
  task send_welcome_emails: :environment do
    ACP.enter!('ragedevert')
    Member
      .active
      .where(welcome_email_sent_at: nil)
      .find_each(&:send_welcome_email)
    puts "#{Current.acp.name}: Welcome emails send to new active members."
  end

  desc 'Ensure that members active/inactive state are up to date'
  task review_active_state: :environment do
    ACP.enter_each! do
      Member.includes(:current_or_future_membership).each(&:review_active_state!)
      puts "#{Current.acp.name}: Members active/inactive state reviewed."
    end
  end
end
