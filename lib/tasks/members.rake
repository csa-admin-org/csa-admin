namespace :members do
  desc 'Send welcome emails to new active members'
  task send_welcome_emails: :environment do
    WelcomeEmailSender.send
    p 'Welcome emails send to new members.'
  end
end
