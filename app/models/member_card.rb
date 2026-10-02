# frozen_string_literal: true

class MemberCard < ApplicationRecord
  belongs_to :member
  belongs_to :price_reduction_card

  validates :price_reduction_card_id, uniqueness: { scope: :member_id }
  validate :required_fields_present

  scope :expiring_within, ->(date) {
    where(expires_on: ..date).where.not(expires_on: nil)
  }

  def complete?
    type = price_reduction_card
    return false unless type
    return false if type.require_name? && name.blank?
    return false if type.require_number? && number.blank?
    return false if type.require_expires_on? && expires_on.blank?

    true
  end

  def valid_on?(date = Date.current)
    return false unless complete?
    return true unless price_reduction_card.require_expires_on?

    expires_on >= date
  end

  def notice_due?(on: Date.current, delay_in_days: MailTemplate.delay_in_days_for("price_reduction_card_expiring"))
    return false unless price_reduction_card.require_expires_on?
    return false unless expires_on
    return false if expiration_notice_sent_on == expires_on

    expires_on <= on + delay_in_days.days
  end

  def masked_number
    return if number.blank?

    visible = number.last(4)
    ("•" * [ number.length - visible.length, 0 ].max) + visible
  end

  private

  def required_fields_present
    type = price_reduction_card
    return unless type

    errors.add(:name, :blank) if type.require_name? && name.blank?
    errors.add(:number, :blank) if type.require_number? && number.blank?
    errors.add(:expires_on, :blank) if type.require_expires_on? && expires_on.blank?
  end
end
