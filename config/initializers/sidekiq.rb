module Sidekiq::Middleware::Tenant
  class Client
    def call(_worker_class, msg, _queue, _redis_pool)
      unless Tenant.outside?
        msg['acp_tenant_name'] ||= Tenant.current
        msg['tags'] ||= []
        msg['tags'] << Tenant.current
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
    chain.prepend Sidekiq::Middleware::Tenant::Client
  end
end

Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    chain.prepend Sidekiq::Middleware::Tenant::Client
  end
  config.server_middleware do |chain|
    chain.prepend Sidekiq::Middleware::Tenant::Server
  end
end
