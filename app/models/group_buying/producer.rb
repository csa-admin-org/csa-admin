module GroupBuying
  class Producer < ActiveRecord::Base
    self.table_name = 'group_buying_producers'

    include HasTranslatedDescription

    has_many :products, class_name: 'GroupBuying::Product'

    validates :name, presence: true

    def can_destroy?
      products.none?
    end
  end
end
