# frozen_string_literal: true

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

  # Sessions already deleted on discard; nullify to avoid FK issues.
  def nullify_related_session_ids!
    absences.update_all(session_id: nil)
    activity_participations.update_all(session_id: nil)
  end

  def anonymize_absences!
    absences.update_all(note: nil)
  end

  def anonymize_activity_participations!
    activity_participations.update_all(
      note: nil,
      carpooling_phone: nil,
      carpooling_city: nil
    )
  end

  def delete_mail_deliveries!
    MailDelivery::Email.where(mail_delivery_id: mail_deliveries.select(:id)).delete_all
    mail_deliveries.delete_all
  end

  # Comments may contain PII even on non-PII resources.
  def delete_comments!
    ActiveAdmin::Comment.where(resource: self).delete_all
    ActiveAdmin::Comment.where(resource_type: "Absence", resource_id: absences.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "ActivityParticipation", resource_id: activity_participations.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Payment", resource_id: payments.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Invoice", resource_id: invoices.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Membership", resource_id: memberships.select(:id)).delete_all
    ActiveAdmin::Comment.where(resource_type: "Shop::Order", resource_id: shop_orders.select(:id)).delete_all
  end

  def delete_audits!
    audits.delete_all
  end

  def delete_sessions!
    sessions.delete_all
  end
end
