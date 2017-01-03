class Vegetable < ApplicationRecord
  has_many :basket_contents

  default_scope { order(:name) }

  validates :name, presence: true, uniqueness: true
end
