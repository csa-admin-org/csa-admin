# frozen_string_literal: true

# Handles automatic cleanup of old MailDelivery records.
#
# Delivery records are kept for RETENTION_PERIOD (1 year) and then
# automatically purged by Scheduled::MailDeliveriesPurgeJob.
module MailDelivery::Retention
  extend ActiveSupport::Concern

  RETENTION_PERIOD = 1.year

  included do
    scope :expired, -> { where("created_at < ?", RETENTION_PERIOD.ago) }
  end

  class_methods do
    def purge_expired!
      transaction do
        expired_scope = expired
        MailDelivery::Email.where(mail_delivery_id: expired_scope.select(:id)).delete_all
        expired_scope.delete_all
      end
    end
  end
end
