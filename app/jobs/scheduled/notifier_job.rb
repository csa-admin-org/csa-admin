module Scheduled
  class NotifierJob < BaseJob
    retry_on StandardError, attempts: 10

    def perform
      Notifier.send_all
    end
  end
end
