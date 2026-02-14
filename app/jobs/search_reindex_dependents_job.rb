# frozen_string_literal: true

class SearchReindexDependentsJob < ApplicationJob
  queue_as :low

  def perform(record)
    SearchEntry.reindex_dependents!(record)
  end
end
