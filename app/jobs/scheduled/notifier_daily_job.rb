# frozen_string_literal: true

module Scheduled
  class NotifierDailyJob < BaseJob
    NOTIFICATIONS = [
      Notification::InvoiceOverdueNotice,
      Notification::AdminDeliveryList,
      Notification::AdminMembershipsRenewalPending,
      Notification::BasketInitial,
      Notification::BasketFinal,
      Notification::BasketFirst,
      Notification::BasketLast,
      Notification::BasketSecondLastTrial,
      Notification::BasketLastTrial,
      Notification::MembershipRenewalReminder,
      Notification::ActivityParticipationReminder,
      Notification::ActivityParticipationValidated,
      Notification::ActivityParticipationRejected,
      Notification::BiddingRoundOpenedReminder
    ].freeze

    def perform
      NOTIFICATIONS.each(&:notify_later)
    end
  end
end
