# frozen_string_literal: true

class BasketComplement < ApplicationRecord
  MEMBER_ORDER_MODES = %w[
    name_asc
    price_asc
    price_desc
    deliveries_count_asc
    deliveries_count_desc
  ]

  include TranslatedAttributes
  include HasPublicName
  include HasVisibility
  include HasPrice
  include Discardable

  translated_attributes :form_detail

  has_many :baskets_basket_complement, dependent: :destroy
  has_many :baskets, through: :baskets_basket_complement
  has_many :memberships_basket_complements, dependent: :destroy
  has_many :memberships, through: :memberships_basket_complements
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

  after_commit :update_basket_basket_complements_async

  scope :ordered, -> { order_by_name }
  scope :used, -> {
    ids = BasketsBasketComplement
      .joins(:delivery)
      .merge(Delivery.current_and_future_year)
      .pluck(:basket_complement_id)
      .uniq
    where(id: ids)
  }

  validates :activity_participations_demanded_annually,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true

  def self.for(baskets, shop_orders = Shop::Order.none)
    ids =
      baskets
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { quantity: 1.. })
        .pluck(:basket_complement_id)
    ids +=
      shop_orders
        .joins(:products)
        .pluck(shop_products: :basket_complement_id)
    where(id: ids.uniq).ordered
  end

  def self.member_ordered
    all.to_a.sort_by { |bc|
      clauses = [ bc.member_order_priority ]
      clauses <<
        case Current.org.basket_complements_member_order_mode
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

  def can_delete?
    memberships_basket_complements.none? && baskets_basket_complement.none? && !shop_product
  end

  def can_discard?
    memberships.current_and_future_year.none? && baskets.current_and_future_year.none? && !shop_product
  end

  private

  def after_add_delivery!(delivery)
    deliveries_change[:added] << delivery.id
  end

  def after_remove_delivery!(delivery)
    deliveries_change[:removed] << delivery.id
  end

  def deliveries_change
    @deliveries_change ||= { added: [], removed: [] }
  end

  def update_basket_basket_complements_async
    return unless deliveries_change.any?(&:present?)

    BasketsBasketComplementsUpdaterJob.perform_later(self, deliveries_change)
  end
end
