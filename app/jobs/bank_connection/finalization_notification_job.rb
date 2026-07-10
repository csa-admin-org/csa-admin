# frozen_string_literal: true

class BankConnection::FinalizationNotificationJob < ApplicationJob
  queue_as :low

  def perform(notification_id)
    BankConnection::FinalizationNotification.find_by(id: notification_id)&.deliver!
  end
end
