# frozen_string_literal: true

class BasketSize < ApplicationRecord
  MEMBER_ORDER_MODES = %w[
    name_asc
    price_asc
    price_desc
  ]

  include TranslatedAttributes
  include HasPublicName
  include HasPrice
  include HasVisibility
  include Discardable

  translated_attributes :form_detail

  belongs_to :delivery_cycle, optional: true
  has_many :memberships
  has_many :members, through: :memberships
  has_many :baskets, through: :memberships

  scope :ordered, -> { order(:price).order_by_name }
  scope :member_ordered, -> {
    order_clauses = [ "member_order_priority" ]
    order_clauses <<
      case Current.org.basket_sizes_member_order_mode
      when "price_asc"; "price ASC"
      when "price_desc"; "price DESC"
      end
    order_clauses << "COALESCE(NULLIF(json_extract(public_names, '$.#{I18n.locale}'), ''), json_extract(names, '$.#{I18n.locale}'))"
    reorder(Arel.sql(order_clauses.compact.join(", ")))
  }
  scope :used, -> {
    ids = Basket
      .joins(:delivery)
      .merge(Delivery.current_and_future_year)
      .pluck(:basket_size_id)
      .uniq
    where(id: ids)
  }

  validates :activity_participations_demanded_annually,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true
  validates :shares_number,
    numericality: { greater_than_or_equal_to: 1 },
    allow_nil: true

  def self.for(baskets)
    ids = baskets.where(baskets: { quantity: 1.. }).pluck(:basket_size_id).uniq
    where(id: ids).ordered
  end

  def display_name; name end

  def can_delete?
    memberships.none? && baskets.none?
  end

  def can_discard?
    memberships.current_and_future_year.none? && baskets.current_and_future_year.none?
  end

  def price_for(year)
    Basket
      .during_year(year)
      .where(basket_size: self)
      .pluck(:basket_size_price)
      .group_by(&:itself)
      .max_by(&:size)
      &.first || 0
  end

  def billable_deliveries_counts
    if delivery_cycle
      [ delivery_cycle.billable_deliveries_count ]
    else
      DeliveryCycle.billable_deliveries_counts
    end
  end
end
