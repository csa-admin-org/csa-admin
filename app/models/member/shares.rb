# frozen_string_literal: true

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
      if: -> { public_create && Current.org.feature?("shares") }

    before_save :handle_required_shares_number_change, if: :shares_configuration_changed?
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
      update_columns(
        state: Member::INACTIVE_STATE,
        desired_shares_number: 0)
    end
  end

  private

  def shares_configuration_changed?
    will_save_change_to_existing_shares_number? ||
      will_save_change_to_desired_shares_number? ||
      will_save_change_to_required_shares_number?
  end

  def handle_required_shares_number_change
    return unless Current.org.feature?("shares")

    final_shares_number = [ shares_number, desired_shares_number ].max
    if (final_shares_number + required_shares_number).positive?
      self.state = Member::SUPPORT_STATE if inactive?
    elsif support?
      self.desired_shares_number = 0
      self.state = Member::INACTIVE_STATE
    end
  end
end
