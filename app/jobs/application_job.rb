# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  include TenantContext

  retry_on ActiveRecord::Deadlocked
  retry_on ActiveStorage::FileNotFoundError

  discard_on ActiveJob::DeserializationError
end
