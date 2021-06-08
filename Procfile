web: bundle exec puma -C config/puma.rb
worker: env DB_POOL=8 bin/sidekiq -c 4
