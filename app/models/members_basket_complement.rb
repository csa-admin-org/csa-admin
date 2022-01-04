class MembersBasketComplement < ApplicationRecord
  belongs_to :member, touch: true
  belongs_to :basket_complement

  validates :basket_complement_id, uniqueness: { scope: :member_id }
  validates :quantity, numericality: { greater_than_or_equal_to: 1 }, presence: true
end
