# frozen_string_literal: true

# Handles GDPR-compliant anonymization of member PII data.
# Called after a configurable delay following discard.
#
# On anonymize:
# - Member PII cleared (name, emails, phones, address, notes, SEPA, etc.)
# - Related records scrubbed (absences, activity participations)
# - Deleted: sessions, mail deliveries, audits, admin comments
module Member::Anonymization
  extend ActiveSupport::Concern

  DELAY_IN_DAYS = 30

  included do
    scope :anonymizable, -> {
      discarded
        .where(anonymized_at: nil)
        .where(discarded_at: ..DELAY_IN_DAYS.days.ago)
    }
  end

  def anonymize!
    raise "Cannot anonymize non-discarded member ##{id}" unless discarded?
    raise "Member ##{id} is already anonymized" if anonymized?

    transaction do
      nullify_related_session_ids!
      anonymize_member_pii!
      anonymize_absences!
      anonymize_activity_participations!
      delete_mail_deliveries!
      delete_comments!
      delete_audits!
      delete_sessions!
    end
  end

  def can_anonymize?
    discarded? && !anonymized?
  end

  def anonymized?
    anonymized_at?
  end

  private

  # Member PII fields to clear (per GDPR data map)
  def anonymize_member_pii!
    update_columns(
      name: "DELETED",
      emails: nil,
      phones: nil,
      street: nil,
      zip: nil,
      city: nil,
      country_code: nil,
      billing_email: nil,
      billing_name: nil,
      billing_street: nil,
      billing_zip: nil,
      billing_city: nil,
      note: nil,
      delivery_note: nil,
      food_note: nil,
      profession: nil,
      come_from: nil,
      iban: nil,
      sepa_mandate_id: nil,
      sepa_mandate_signed_on: nil,
      contact_sharing: false,
      anonymized_at: Time.current
    )
  end

  # Nullify session_id references before sessions are deleted
  # to avoid FK issues (sessions already deleted on discard)
  def nullify_related_session_ids!
    absences.update_all(session_id: nil)
    activity_participations.update_all(session_id: nil)
  end

  # Clear note field from absences
  def anonymize_absences!
    absences.update_all(note: nil)
  end

  # Clear PII fields from activity participations
  def anonymize_activity_participations!
    activity_participations.update_all(
      note: nil,
      carpooling_phone: nil,
      carpooling_city: nil
    )
  end

  # Delete mail deliveries and their email children (contain personalized content)
  def delete_mail_deliveries!
    MailDelivery::Email.where(mail_delivery_id: mail_deliveries.select(:id)).delete_all
    mail_deliveries.delete_all
  end

  # Delete all admin comments on member and related records
  # Comments may contain PII even on non-PII resources (e.g., notes about the member)
  def delete_comments!
    ActiveAdmin::Comment.where(resource: self).delete_all
    ActiveAdmin::Comment.where(resource_type: "Absence", resource_id: absences.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "ActivityParticipation", resource_id: activity_participations.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Payment", resource_id: payments.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Invoice", resource_id: invoices.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Membership", resource_id: memberships.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Shop::Order", resource_id: shop_orders.select(:id)).delete_all
  end

  # Delete all audit records for member
  # Member audits contain PII values (name, emails, phones, etc.) in audited_changes
  def delete_audits!
    audits.delete_all
  end

  # Delete all sessions (already revoked on discard, now permanently removed)
  def delete_sessions!
    sessions.delete_all
  end
end
