# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  include TenantContext

  self.enqueue_after_transaction_commit = true

  retry_on ActiveRecord::Deadlocked
  retry_on ActiveRecord::StatementTimeout, wait: 5.seconds, attempts: 3
  retry_on ActiveStorage::FileNotFoundError

  # Missing GlobalID only. A transient DB error while deserializing must fail
  # the job, not disappear. Scheduled jobs still retry via retry_on Exception.
  discard_on ActiveJob::DeserializationError::RecordNotFound
end
