class Vegetable < ApplicationRecord
  include TranslatedAttributes

  translated_attributes :name

  has_many :basket_contents
  has_many :deliveries, through: :basket_contents

  default_scope { order_by_name }

  validates :names, presence: true, uniqueness: true
end
