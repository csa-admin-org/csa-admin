module Scheduled
  class PostmarkSyncSuppressionsBatchJob < BaseJob
    def perform
      ACP.perform_each do
        PostmarkSyncSuppressionsJob.perform_later
      end
    end
  end
end
