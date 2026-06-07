# frozen_string_literal: true

module Organization::VatFeature
  extend ActiveSupport::Concern

  included do
    with_options if: -> { feature?("vat") } do
      validates :vat_number, presence: true
      validates :vat_membership_rate, presence: true
    end

    validates :vat_membership_rate,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :vat_activity_rate,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :vat_shop_rate,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  end

  def vat?
    feature?("vat")
  end
end
