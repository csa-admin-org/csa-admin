namespace :sidekiq do
  desc 'Check if Sidekiq worker process is running'
  task check_health: :environment do
    ps = Sidekiq::ProcessSet.new
    if ps.none?
      Sentry.capture_message('Sidekiq worker process is not running')
    end
  end
end
