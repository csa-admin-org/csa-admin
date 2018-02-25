namespace :halfdays do
  desc 'Send coming halfday emails'
  task send_coming_emails: :environment do
    ACP.switch_each! do
      HalfdayParticipation.send_coming_mails
      p "#{Current.acp.name}: Coming halfday emails sent."
    end
  end
end
