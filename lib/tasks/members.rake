namespace :members do
  desc 'Send welcome emails to new active members'
  task send_welcome_emails: :environment do
    WelcomeEmailSender.send
    p 'Welcome emails send to new members.'
  end

  desc 'Ensure that members state are up to date'
  task update_state: :environment do
    Member.all.each(&:update_state!)
    p 'Members state updated.'
  end
end
