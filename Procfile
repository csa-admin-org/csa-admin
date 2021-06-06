web: bundle exec puma -C config/puma.rb
worker: env DB_POOL=10 bin/sidekiq -c 5
