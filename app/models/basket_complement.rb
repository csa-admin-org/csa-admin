class BasketComplement < ApplicationRecord
  include TranslatedAttributes
  include HasVisibility

  MEMBER_ORDER_MODES = %w[
    name_asc
    price_asc
    price_desc
    deliveries_count_asc
    deliveries_count_desc
  ]

  translated_attributes :name, required: true
  translated_attributes :public_name
  translated_attributes :form_detail

  has_many :baskets_basket_complement, dependent: :destroy
  has_many :memberships_basket_complements, dependent: :destroy
  has_one :shop_product, class_name: "Shop::Product"
  has_and_belongs_to_many :deliveries, validate: false
  has_and_belongs_to_many :current_deliveries, -> { current_year },
    class_name: "Delivery",
    validate: false,
    after_add: :after_add_delivery!,
    after_remove: :after_remove_delivery!
  has_and_belongs_to_many :future_deliveries, -> { future_year },
    class_name: "Delivery",
    validate: false,
    after_add: :after_add_delivery!,
    after_remove: :after_remove_delivery!

  default_scope { order_by_name }

  scope :used, -> {
    ids = BasketsBasketComplement
      .joins(:delivery)
      .merge(Delivery.current_and_future_year)
      .pluck(:basket_complement_id)
      .uniq
    where(id: ids)
  }

  validates :price,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true
  validates :activity_participations_demanded_annualy,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true

  def self.for(baskets, shop_orders)
    ids =
      baskets
        .joins(:baskets_basket_complements)
        .where("baskets_basket_complements.quantity > 0")
        .pluck(:basket_complement_id)
    ids +=
      shop_orders
        .joins(:products)
        .pluck("shop_products.basket_complement_id")
    where(id: ids.uniq)
  end

  def self.member_ordered
    all.to_a.sort_by { |bc|
      clauses = [ bc.member_order_priority ]
      clauses <<
        case Current.acp.basket_complements_member_order_mode
        when "price_asc"; bc.price
        when "price_desc"; -bc.price
        when "deliveries_count_asc"; bc.deliveries_count
        when "deliveries_count_desc"; -bc.deliveries_count
        end
      clauses << bc.public_name
      clauses
    }
  end

  def billable_deliveries_counts
    DeliveryCycle.billable_deliveries_count_for(self)
  end

  def deliveries_count
    @deliveries_count ||= begin
      future_count = future_deliveries.count
      future_count.positive? ? future_count : current_deliveries.count
    end
  end

  def delivery_ids
    @delivery_ids ||= begin
      future_count = future_deliveries.count
      future_count.positive? ? future_deliveries.pluck(:id) : current_deliveries.pluck(:id)
    end
  end

  def current_and_future_delivery_ids
    @current_and_future_delivery_ids ||= deliveries.current_and_future_year.pluck(:id)
  end

  def display_name; name end

  def public_name
    self[:public_names][I18n.locale.to_s].presence || name
  end

  def can_destroy?
    memberships_basket_complements.none? && baskets_basket_complement.none? && !shop_product
  end

  private

  def after_add_delivery!(delivery)
    BasketsBasketComplement.handle_deliveries_addition!(delivery, self)
  end

  def after_remove_delivery!(delivery)
    BasketsBasketComplement.handle_deliveries_removal!(delivery, self)
  end
end
