class MembersBasketComplement < ApplicationRecord
  include HasDescription

  belongs_to :member, touch: true
  belongs_to :basket_complement

  validates :basket_complement_id, uniqueness: { scope: :member_id }
  validates :quantity, numericality: { greater_than_or_equal_to: 1 }, presence: true

  def description(public_name: false)
    describe(basket_complement, quantity, public_name: public_name)
  end
end
