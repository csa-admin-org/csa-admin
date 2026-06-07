# frozen_string_literal: true

module Organization::SharesFeature
  extend ActiveSupport::Concern

  included do
    with_options if: -> { feature?("shares") } do
      validates :share_price, presence: true
      validates :shares_number, presence: true
    end

    validates :share_price,
      numericality: { greater_than_or_equal_to: 1 },
      allow_nil: true
    validates :shares_number,
      numericality: { greater_than_or_equal_to: 1 },
      allow_nil: true
  end

  def shares?
    feature?("shares")
  end

  def share?
    shares?
  end
end
