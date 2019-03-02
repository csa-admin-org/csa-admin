namespace :activity_participations do
  desc 'Send activity participations reminder emails'
  task send_reminder_emails: :environment do
    ACP.enter_each! do
      ActivityParticipation
        .coming
        .includes(:activity)
        .find_each(&:send_reminder_email)
      puts "#{Current.acp.name}: activity participations reminder emails sent."
    end
  end
end
