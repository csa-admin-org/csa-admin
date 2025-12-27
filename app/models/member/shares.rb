# frozen_string_literal: true

# Handles share-related logic for members.
# This includes tracking existing, required, and desired shares,
# calculating missing shares, and handling share changes.
module Member::Shares
  extend ActiveSupport::Concern

  included do
    validates :existing_shares_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :required_shares_number, numericality: { allow_nil: true }
    validates :desired_shares_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :desired_shares_number,
      numericality: {
        greater_than_or_equal_to: ->(m) { m.waiting_basket_size&.shares_number || Current.org.shares_number || 0 }
      },
      if: -> { public_create && Current.org.share? }

    before_save :handle_required_shares_number_change
  end

  def shares_number
    existing_shares_number.to_i + invoices.not_canceled.share.sum(:shares_number)
  end

  def required_shares_number=(value)
    self[:required_shares_number] = value.presence
  end

  def required_shares_number
    (self[:required_shares_number]
      || default_required_shares_number).to_i
  end

  def default_required_shares_number
    current_or_future_membership&.basket_size&.shares_number.to_i
  end

  def missing_shares_number
    [ [ required_shares_number, desired_shares_number ].max - shares_number, 0 ].max
  end

  def handle_shares_change!
    if shares_number.positive?
      update_column(:state, Member::SUPPORT_STATE) if inactive?
    elsif support?
      update_column(:state, Member::INACTIVE_STATE)
    end
  end

  private

  def handle_required_shares_number_change
    return unless Current.org.share?

    final_shares_number = [ shares_number, desired_shares_number ].max
    if (final_shares_number + required_shares_number).positive?
      self.state = Member::SUPPORT_STATE if inactive?
    elsif support?
      self.desired_shares_number = 0
      self.state = Member::INACTIVE_STATE
    end
  end
end
