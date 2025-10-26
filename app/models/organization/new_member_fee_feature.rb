# frozen_string_literal: true

module Organization::NewMemberFeeFeature
  extend ActiveSupport::Concern

  included do
    translated_attributes :new_member_fee_description

    validates :new_member_fee,
      presence: true,
      numericality: { greater_than_or_equal_to: 0 },
      if: -> { feature?("new_member_fee") && new_member_fee_description? }
    validates :new_member_fee_description,
      presence: true,
      if: -> { feature?("new_member_fee") && new_member_fee? }
  end
end
