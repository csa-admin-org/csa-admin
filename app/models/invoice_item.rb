require 'rounding'

class InvoiceItem < ApplicationRecord
  belongs_to :invoice

  validates :description, presence: true
  validates :amount, presence: true, numericality: { other_than: 0 }

  def amount=(amount)
    super(BigDecimal(amount).round_to_five_cents)
  end
end
