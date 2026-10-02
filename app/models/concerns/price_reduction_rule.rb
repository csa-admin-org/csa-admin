# frozen_string_literal: true

# Shared cut formula for a catalog program and the copy stored on a grant.
#
# percentage and fixed_amount are mutually exclusive. The cut never exceeds
# the membership gross.
module PriceReductionRule
  extend ActiveSupport::Concern

  FIELDS = %i[percentage fixed_amount].freeze

  included do
    validates :percentage,
      numericality: { greater_than: 0, less_than_or_equal_to: 100 },
      allow_nil: true
    validates :fixed_amount,
      numericality: { greater_than: 0 },
      allow_nil: true
    validate :percentage_xor_fixed_amount
  end

  def raw_amount(gross)
    gross = gross.to_d
    base =
      if fixed_amount
        fixed_amount.to_d
      elsif percentage
        gross * percentage.to_d / 100
      else
        0
      end
    base = [ base, gross ].min
    [ base, 0 ].max.round_to_five_cents
  end

  private

  def percentage_xor_fixed_amount
    return if percentage.present? ^ fixed_amount.present?

    errors.add(:base, :percentage_xor_fixed_amount)
  end
end
