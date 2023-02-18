module Sidekiq::Middleware::Tenant
  class Client
    def call(_worker_class, msg, _queue, _redis_pool)
      unless Tenant.outside?
        msg['tags'] ||= []
        msg['tags'] << Tenant.current
      end
      yield
    end
  end
end

Sidekiq.configure_client do |config|
  config.logger = Rails.logger if Rails.env.test?
  config.client_middleware do |chain|
    chain.prepend Sidekiq::Middleware::Tenant::Client
  end
end

Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    chain.prepend Sidekiq::Middleware::Tenant::Client
  end
end
