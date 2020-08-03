namespace :memberships do
  desc 'Update all current memberships cached basket counts'
  task update_baskets_counts: :environment do
    ACP.enter_each! do
      Membership.current.find_each(&:update_baskets_counts!)
      puts "#{Current.acp.name}: Memberships basket counts updated."
    end
  end

  desc 'Send open renewal reminders'
  task send_renewal_reminders: :environment do
    ACP.enter_each! do
      Membership.send_renewal_reminders!
    end
  end
end
