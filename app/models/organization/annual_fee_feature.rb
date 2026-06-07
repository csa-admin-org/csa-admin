# frozen_string_literal: true

module Organization::AnnualFeeFeature
  extend ActiveSupport::Concern

  included do
    validates :annual_fee, presence: true, if: -> { feature?("annual_fee") }
    validates :annual_fee,
      numericality: { greater_than_or_equal_to: 0 },
      allow_nil: true

    after_save :apply_annual_fee_change
  end

  def annual_fee?
    feature?("annual_fee")
  end

  private

  def apply_annual_fee_change
    return unless annual_fee_previously_changed?

    Member
      .where(annual_fee: annual_fee_previously_was)
      .update_all(annual_fee: annual_fee)
  end
end
