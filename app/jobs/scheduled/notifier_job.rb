module Scheduled
  class NotifierJob < BaseJob
    def perform
      Notifier.send_all
    end
  end
end
