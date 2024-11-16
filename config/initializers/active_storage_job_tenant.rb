# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActiveStorage::BaseJob.include(TenantContext)
end
