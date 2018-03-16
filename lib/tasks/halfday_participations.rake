namespace :halfday_participations do
  desc 'Send halfday participations reminder emails'
  task send_reminder_emails: :environment do
    ACP.enter_each! do
      HalfdayParticipation.send_reminder_emails
      p "#{Current.acp.name}: halfday participations reminder emails sent."
    end
  end
end
