# frozen_string_literal: true

module Scheduled
  class NotifierDailyJob < BaseJob
    NOTIFICATIONS = [
      Notification::InvoiceOverdueNotice,
      Notification::AdminDeliveryList,
      Notification::BasketComplementDeliveryCount,
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
      Notification::BiddingRoundOpenedReminder,
      Notification::MemberCardExpiring
    ].freeze

    def perform
      NOTIFICATIONS.each_with_index do |notification, index|
        notification.notify_later(wait: index.seconds)
      end
    end
  end
end
