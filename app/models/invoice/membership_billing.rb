# frozen_string_literal: true

# Handles membership-specific billing logic for invoices.
# This includes calculating membership amounts, tracking paid and remaining
# amounts, and validating that billing doesn't exceed membership price.
module Invoice::MembershipBilling
  extend ActiveSupport::Concern

  included do
    with_options if: :membership_type?, on: :create do
      before_validation \
        :set_paid_memberships_amount,
        :set_remaining_memberships_amount,
        :set_memberships_amount
    end

    validates :membership_amount_fraction, inclusion: { in: 1..12 }
    validates :paid_memberships_amount,
      numericality: { greater_than_or_equal_to: 0 },
      allow_nil: true
    validates :memberships_amount,
      numericality: { greater_than: 0 },
      allow_nil: true
    validates :memberships_amount_description,
      presence: true,
      if: -> { memberships_amount? }
    validate :memberships_amount_not_too_high,
      on: :create,
      if: :membership_type?
  end

  def membership_amount_fraction
    @membership_amount_fraction || 1 # bill for everything by default
  end

  def memberships_amount=(*_args)
    raise NoMethodError, "is set automaticaly."
  end

  def remaining_memberships_amount=(*_args)
    raise NoMethodError, "is set automaticaly."
  end

  private

  def set_paid_memberships_amount
    paid_invoices = entity.invoices.not_canceled
    self[:paid_memberships_amount] ||= paid_invoices.sum(:memberships_amount)
  end

  def set_remaining_memberships_amount
    self[:remaining_memberships_amount] ||= entity.price - paid_memberships_amount
  end

  def set_memberships_amount
    amount = remaining_memberships_amount / membership_amount_fraction.to_f
    self[:memberships_amount] ||= amount.round_to_five_cents
  end

  def memberships_amount_not_too_high
    paid_invoices = entity.invoices.not_canceled
    if paid_invoices.sum(:memberships_amount) + memberships_amount > entity.price
      errors.add(:base, "Somme de la facturation des abonnements trop grande")
    end
  end
end
