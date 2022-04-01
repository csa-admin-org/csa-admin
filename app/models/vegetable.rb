class Vegetable < ApplicationRecord
  include TranslatedAttributes

  translated_attributes :name

  has_many :basket_contents
  has_many :deliveries, through: :basket_contents

  has_one :latest_basket_content, -> {
    joins(:delivery).merge(Delivery.unscoped.order(date: :desc) )
  }, class_name: 'BasketContent'

  default_scope { order_by_name }

  validates :names, presence: true, uniqueness: true

  def can_destroy?
    basket_contents.none?
  end
end
