# frozen_string_literal: true

module Scheduled
  class SearchRebuildJob < BaseJob
    def perform
      SearchEntry.rebuild!
    end
  end
end
