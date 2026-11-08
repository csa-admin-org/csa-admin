# frozen_string_literal: true

module Scheduled
  class PromotionsArchiverJob < BaseJob
    def perform
      Promotion.archive_ended!
    end
  end
end
