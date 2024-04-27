module HasPrice
  extend ActiveSupport::Concern

  included do
    scope :free, -> { kept.where(price: 0) }
    scope :paid, -> { kept.where(arel_table[:price].gt(0)) }

    validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  end

  class_methods do
    def ransackable_scopes(_auth_object = nil)
      super + %i[wday month]
    end
  end

  def free?
    price.zero?
  end

  def paid?
    price.positive?
  end
end
