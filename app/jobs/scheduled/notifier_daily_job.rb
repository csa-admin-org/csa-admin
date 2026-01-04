# frozen_string_literal: true

module Scheduled
  class NotifierDailyJob < BaseJob
    NOTIFICATIONS = [
      Notification::InvoiceOverdueNotice,
      Notification::AdminDeliveryList,
      Notification::AdminMembershipsRenewalPending,
      Notification::MembershipInitialBasket,
      Notification::MembershipFinalBasket,
      Notification::MembershipFirstBasket,
      Notification::MembershipLastBasket,
      Notification::MembershipSecondLastTrialBasket,
      Notification::MembershipLastTrialBasket,
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
