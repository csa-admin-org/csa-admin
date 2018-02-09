class MembershipsBasketComplement < ActiveRecord::Base
  belongs_to :membership
  belongs_to :basket_complement

  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 1 }, presence: true

  before_validation do
    self.price ||= basket_complement&.price
  end

  def name
    "#{"#{quantity} x " if quantity > 1}#{basket_complement.name}"
  end

  def total_price
    quantity * price
  end
end
