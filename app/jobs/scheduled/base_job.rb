module Scheduled
  class BaseJob < ApplicationJob
    queue_as :low
  end
end
