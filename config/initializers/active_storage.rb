# frozen_string_literal: true

class ActiveStorage::BaseJob < ActiveJob::Base
  retry_on Aws::S3::Errors::InternalError
end
