class BasketsBasketComplement < ActiveRecord::Base
  belongs_to :basket
  belongs_to :basket_complement

  before_create do
    self.price = basket_complement.price
  end
end
