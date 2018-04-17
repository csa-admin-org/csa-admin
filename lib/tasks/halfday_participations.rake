namespace :halfday_participations do
  desc 'Send halfday participations reminder emails'
  task send_reminder_emails: :environment do
    ACP.enter_each! do
      HalfdayParticipation
        .coming
        .includes(:halfday)
        .find_each(&:send_reminder_email)
      p "#{Current.acp.name}: halfday participations reminder emails sent."
    end
  end
end
