# frozen_string_literal: true

module Scheduled
  class MembersAnonymizerJob < BaseJob
    def perform
      Member.anonymizable.find_each do |member|
        member.anonymize!
        Rails.logger.info "Anonymized member ##{member.id}"
      end
    end
  end
end
