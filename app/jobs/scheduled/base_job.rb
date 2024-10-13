# frozen_string_literal: true

module Scheduled
  class BaseJob < ApplicationJob
    retry_on Exception, wait: :polynomially_longer, attempts: 5
    queue_as :low
  end
end
