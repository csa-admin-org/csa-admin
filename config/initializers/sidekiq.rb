module Sidekiq::Middleware::Apartement
  class Client
    def call(_worker_class, msg, _queue, _redis_pool)
      unless Apartment::Tenant.current == 'public'
        msg['acp_tenant_name'] ||= Apartment::Tenant.current
      end
      yield
    end
  end

  class Server
    def call(_worker, msg, _queue, &blk)
      if acp_tenant_name = msg['acp_tenant_name']
        ACP.perform(acp_tenant_name, &blk)
      else
        yield
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.prepend Sidekiq::Middleware::Apartement::Client
  end
end

Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    chain.prepend Sidekiq::Middleware::Apartement::Client
  end
  config.server_middleware do |chain|
    chain.prepend Sidekiq::Middleware::Apartement::Server
  end
end
