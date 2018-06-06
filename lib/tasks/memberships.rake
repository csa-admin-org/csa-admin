namespace :memberships do
  desc 'Update all current memberships cached basket counts'
  task update_baskets_counts: :environment do
    ACP.enter_each! do
      Membership.current.find_each(&:update_baskets_counts!)
      puts "#{Current.acp.name}: Memberships basket counts updated."
    end
  end
end
