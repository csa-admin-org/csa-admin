class BasketContent
  class Product < ApplicationRecord
    include TranslatedAttributes

    translated_attributes :name, required: true

    has_many :basket_contents
    has_many :deliveries, through: :basket_contents

    with_options class_name: "BasketContent" do
      has_one :latest_basket_content, -> {
        joins(:delivery).merge(Delivery.unscoped.order(date: :desc))
      }
      has_one :latest_basket_content_in_kg, -> {
        joins(:delivery).merge(Delivery.unscoped.order(date: :desc)).in_kg
      }
      has_one :latest_basket_content_in_pc, -> {
        joins(:delivery).merge(Delivery.unscoped.order(date: :desc)).in_pc
      }
    end

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
