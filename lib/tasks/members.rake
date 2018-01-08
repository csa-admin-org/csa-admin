namespace :members do
  desc 'Send welcome emails to new active members'
  task send_welcome_emails: :environment do
    ACP.switch_each! do
      WelcomeEmailSender.send
      p "#{Current.acp.name}: Welcome emails send to new members."
    end
  end

  desc 'Ensure that members state are up to date'
  task update_state: :environment do
    ACP.switch_each! do
      Member.all.each(&:update_state!)
      p "#{Current.acp.name}: Members state updated."
    end
  end
end
