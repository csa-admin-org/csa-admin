# frozen_string_literal: true

module Scheduled
  class MembershipsStaleOpenRenewalsCancelerJob < BaseJob
    def perform
      Membership.cancel_stale_open_renewals
    end
  end
end
