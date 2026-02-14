# frozen_string_literal: true

module Scheduled
  class SearchPruneJob < BaseJob
    def perform
      SearchEntry.prune_stale_entries!
    end
  end
end
