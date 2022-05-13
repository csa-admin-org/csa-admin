class BasketContent
  class Product < ApplicationRecord
    include TranslatedAttributes

    translated_attributes :name, required: true

    has_many :basket_contents
    has_many :deliveries, through: :basket_contents

    has_one :latest_basket_content, -> {
      joins(:delivery).merge(Delivery.unscoped.order(date: :desc) )
    }, class_name: 'BasketContent'

    default_scope { order_by_name }

    validates :names, uniqueness: true

    def url_domain
      return unless url?

      uri = URI.parse(url)
      PublicSuffix.parse(uri.host).to_s
    end

    def can_destroy?
      basket_contents.none?
    end
  end
end
