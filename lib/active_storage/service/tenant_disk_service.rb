# frozen_string_literal: true

require "active_storage/service/disk_service"

module ActiveStorage
  class Service::TenantDiskService < Service::DiskService
    def path_for(key)
      File.join root, Tenant.current, folder_for(key), key
    end
  end
end
