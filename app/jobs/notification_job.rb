# frozen_string_literal: true

class NotificationJob < ApplicationJob
  queue_as :low

  def perform(notification_class_name)
    notification_class_name.constantize.notify
  end
end
