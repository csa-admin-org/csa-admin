namespace :members do
  desc 'Ensure that members active/inactive state are up to date'
  task review_active_state: :environment do
    ACP.perform_each do
      Member.includes(:current_or_future_membership, :last_membership).each(&:review_active_state!)
      puts "#{Current.acp.name}: Members active/inactive state reviewed."
    end
  end
end
