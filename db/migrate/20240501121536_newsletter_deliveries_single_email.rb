class NewsletterDeliveriesSingleEmail < ActiveRecord::Migration[7.1]
  class NewsletterDelivery < ApplicationRecord
    self.table_name = "newsletter_deliveries"
  end

  def change
    add_column :newsletter_deliveries, :email, :string
    add_column :newsletter_deliveries, :email_suppression_ids, :integer, array: true, default: []
    add_column :newsletter_deliveries, :email_suppression_reasons, :string, array: true, default: []

    up_only do
      if Tenant.inside?
        NewsletterDelivery.reset_column_information
        NewsletterDelivery.all.each do |delivery|
          emails = (delivery.emails + delivery.suppressed_emails).uniq.compact

          email = emails.shift
          delivery.update!({
              email: email,
            }.merge(suppressions(delivery, email)))

          emails.each do |email|
            NewsletterDelivery.create!({
              newsletter_id: delivery.newsletter_id,
              member_id: delivery.member_id,
              email: email,
              subject: delivery.subject,
              content: delivery.content,
              delivered_at: delivery.delivered_at,
              created_at: delivery.created_at
            }.merge(suppressions(delivery, email)))
          end
        end
      end
    end
  end

  private

  def suppressions(delivery, email)
    return {} unless email
    return {} if delivery.suppressed_emails.exclude?(email)

    suppressions =
      EmailSuppression
        .where(created_at: ...delivery.created_at)
        .merge(
          EmailSuppression.where(unsuppressed_at: nil).or(
            EmailSuppression.where(unsuppressed_at: delivery.created_at..)))
        .where(email: email)
        .select(:id, :reason)
    {
      email_suppression_ids: suppressions.map(&:id),
      email_suppression_reasons: suppressions.map(&:reason).uniq
    }
  end
end
