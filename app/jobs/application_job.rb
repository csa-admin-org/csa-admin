# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  include TenantContext

  retry_on ActiveRecord::Deadlocked
  retry_on ActiveRecord::StatementTimeout, wait: 5.seconds, attempts: 3
  retry_on ActiveStorage::FileNotFoundError

  discard_on ActiveJob::DeserializationError
end
