namespace :halfday_works do
  desc 'Send coming halfday work emails'
  task send_coming_emails: :environment do
    ComingHalfdayWorkEmailSender.send
    p 'Coming halfday works emails send.'
  end
end
