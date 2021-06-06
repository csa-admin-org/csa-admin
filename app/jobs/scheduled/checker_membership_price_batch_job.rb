module Scheduled
  class CheckerMembershipPriceBatchJob < BaseJob
    def perform
      ACP.perform_each do
        CheckerMembershipPriceJob.perform_later
      end
    end
  end
end
