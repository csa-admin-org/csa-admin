module Scheduled
  class MembershipBasketsCountBatchJob < BaseJob
    def perform
      ACP.perform_each do
        MembershipBasketsCountJob.perform_later
      end
    end
  end
end
