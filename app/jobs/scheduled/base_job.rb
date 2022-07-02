module Scheduled
  class BaseJob < ApplicationJob
    sidekiq_options retry: 5
    queue_as :low
  end
end
