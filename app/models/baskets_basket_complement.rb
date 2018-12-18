class BasketsBasketComplement < ActiveRecord::Base
  belongs_to :basket, touch: true
  belongs_to :basket_complement

  validates :basket_complement_id, uniqueness: { scope: :basket_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :price, numericality: { equal_to: 0 }, if: :basket_complement_annual_price_type?
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true

  before_validation do
    self.price ||= basket_complement&.delivery_price
  end

  def basket_complement_annual_price_type?
    basket_complement&.annual_price_type?
  end

  def description
    case quantity
    when 0 then nil
    when 1 then basket_complement.name
    else "#{quantity} x #{basket_complement.name}"
    end
  end
end
