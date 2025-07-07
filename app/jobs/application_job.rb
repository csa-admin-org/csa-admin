# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  include TenantContext

  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked
  retry_on ActiveStorage::FileNotFoundError

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError
end
