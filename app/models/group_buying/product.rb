module GroupBuying
  class Product < ActiveRecord::Base
    self.table_name = 'group_buying_products'

    include TranslatedAttributes

    translated_attributes :name

    belongs_to :producer, class_name: 'GroupBuying::Producer', optional: false

    scope :available, -> { where(available: true) }

    validates :name, presence: true
    validates :price,
      presence: true,
      numericality: { greater_than_or_equal_to: 0 }
    validates :available, presence: true

    def can_destroy?
      true
    end
  end
end
