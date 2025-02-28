# frozen_string_literal: true

require "active_storage/service/s3_service"

module ActiveStorage
  class Service::TenantS3Service < Service::S3Service
    private

    def object_for(key)
      super [ Tenant.current, key ].join("/")
    end
  end
end
