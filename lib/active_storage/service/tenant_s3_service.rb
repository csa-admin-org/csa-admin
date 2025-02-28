# frozen_string_literal: true

require "active_storage/service/s3_service"

module ActiveStorage
  class Service::TenantS3Service < Service::S3Service
    private

    def object_for(key)
      # Prepend the tenant name to the original key
      super(namespaced_key(key))
    end

    def namespaced_key(key)
      # Assumes Current.tenant.name provides the current tenant's name
      "#{Current.tenant.name}/#{key}"
    end
  end
end
