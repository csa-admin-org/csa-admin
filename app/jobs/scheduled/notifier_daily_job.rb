module Scheduled
  class NotifierDailyJob < BaseJob
    def perform
      Notifier.send_all_daily
    end
  end
end
