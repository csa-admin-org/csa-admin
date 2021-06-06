namespace :memberships do
  desc 'Update all current memberships cached basket counts'
  task update_baskets_counts: :environment do
    ACP.perform_each do
      Membership.current_year.find_each(&:update_baskets_counts!)
      puts "#{Current.acp.name}: Memberships basket counts updated."
    end
  end

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
