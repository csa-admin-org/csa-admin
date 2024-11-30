# frozen_string_literal: true

module HasPrice
  extend ActiveSupport::Concern

  included do
    scope :free, -> { kept.where(price: 0) }
    scope :paid, -> { kept.where(arel_table[:price].gt(0)) }

    validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  end

  def free?
    price.zero?
  end

  def paid?
    price.positive?
  end
end
