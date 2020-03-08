namespace :billing do
  desc 'Create or update quarter snapshot'
  task snapshot: :environment do
    ACP.enter_each! do
      max = Current.fiscal_year.current_quarter_range.max
      range = (max - 1.hour)..max
      if 30.seconds.from_now.in?(range)
        Billing::Snapshot.create_or_update_current_quarter!
      end
    end
  end
end
