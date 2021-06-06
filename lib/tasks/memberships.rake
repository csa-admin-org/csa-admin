namespace :memberships do
  desc 'Send open renewal reminder emails'
  task send_renewal_reminder_emails: :environment do
    ACP.perform_each do
      Membership.send_renewal_reminder_emails!
    end
  end

  desc 'Send last trial basket emails'
  task send_last_trial_basket_emails: :environment do
    ACP.perform_each do
      Membership.send_last_trial_basket_emails!
    end
  end
end
