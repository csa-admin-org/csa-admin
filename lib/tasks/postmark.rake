namespace :postmark do
  desc 'Sync Postmark Suppressions'
  task sync_suppressions: :environment do
    ACP.enter_each! do
      EmailSuppression.sync(fromdate: 1.week.ago)
      puts "#{Current.acp.name}: Email Suppressions list synced."
    end
  end
end
