module Scheduled
  class DailyBatchJob < BaseJob
    def perform
      ACP.perform_each do
        DailyJob.perform_later
      end
    end
  end
end
