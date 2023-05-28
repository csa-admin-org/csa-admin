class Delivery < ApplicationRecord
  include HasFiscalYearScopes
  include BulkDatesInsert

  default_scope { order(:date) }

  has_many :baskets, dependent: :destroy
  has_many :depots, -> { distinct.reorder(:name) }, through: :baskets
  has_many :basket_contents, dependent: :destroy
  has_many :shop_orders,
    class_name: 'Shop::Order',
    dependent: :destroy,
    as: :delivery
  has_and_belongs_to_many :basket_complements,
    after_add: :add_subscribed_baskets_complement!,
    after_remove: :remove_subscribed_baskets_complement!

  scope :between, ->(range) { where(date: range) }
  scope :past, -> { between(...Date.current) }
  scope :coming, -> { between(Date.current..) }
  scope :shop_open, -> { where(shop_open: true) }

  validates :date, uniqueness: true
  validates :date,
    date: { after_or_equal_to: proc { Date.today } },
    if: :date?
  validates :date,
    date: {
      before_or_equal_to: proc { |d|
        Current.acp.fiscal_year_for(d.date_was).end_of_year
      }
    },
    if: :date_was
  validates :bulk_dates_starts_on,
    date: { after_or_equal_to: proc { Date.today } },
    unless: :date?,
    on: :create

  after_commit -> { self.class.update_numbers(fiscal_year) }
  after_commit :update_baskets_async, :reset_deliveries_cycle_cache!

  def self.next
    coming.order(:date).first
  end

  def self.current
    where('date <= ?', Date.current).order(:date).last
  end

  def self.any_in_year?(year)
    during_year(year).any?
  end

  def self.any_next_year?
    any_in_year?(Current.fy_year + 1)
  end

  def self.update_numbers(fiscal_year)
    during_year(fiscal_year).each_with_index do |d, i|
      d.update_column(:number, i + 1)
    end
  end

  def gid
    to_global_id.to_s
  end

  def basket_sizes
    @basket_sizes ||= BasketSize.find(baskets.not_absent.pluck(:basket_size_id))
  end

  def delivered?
    date.past?
  end

  def display_name(format: :medium_long)
    "#{I18n.l(date, format: format)} (#{display_number})"
  end

  def name; display_name; end

  def display_number
    "##{number}"
  end

  def basket_counts(scope: nil)
    BasketCounts.new(self, Depot.pluck(:id), scope: scope)
  end

  def basket_complement_counts(scope: nil)
    BasketComplementCount.all(self, scope: scope)
  end

  def shop_open_for_depots
    Depot.where.not(id: shop_closed_for_depot_ids)
  end

  def shop_open_for_depot_ids
    @shop_open_for_depot_ids ||= shop_open_for_depots.pluck(:id)
  end

  def shop_open_for_depot_ids=(ids)
    @shop_open_for_depot_ids = nil
    self[:shop_closed_for_depot_ids] = Depot.pluck(:id) - ids.map(&:to_i)
  end

  def shop_closing_at
    return nil unless shop_open

    delay_in_days = Current.acp.shop_delivery_open_delay_in_days.to_i.days
    end_time = Current.acp.shop_delivery_open_last_day_end_time || Tod::TimeOfDay.parse('23:59:59')
    limit = end_time.on(date - delay_in_days)
  end

  def shop_open?(depot_id: nil, ignore_closing_at: false)
    return false unless Current.acp.feature?('shop')
    return false unless shop_open
    return false if shop_open_for_depot_ids.empty?

    (ignore_closing_at || !shop_closing_at.past?) &&
      (!depot_id || shop_closed_for_depot_ids.exclude?(depot_id))
  end

  def shop_text
    Current.acp.shop_text
  end

  def available_shop_products(depot)
    Shop::Product.available_for(self, depot)
  end

  def can_destroy?
    date >= Date.today
  end

  def can_update?
    date >= Date.today
  end

  def basket_content_yearly_price_diff(basket_size)
    basket_content_yearly_price_diffs[basket_size.id]
  end

  def basket_content_yearly_price_diffs
    @basket_content_yearly_price_diffs ||= begin
      used_deliveries_cycle_ids = Membership.used_deliveries_cycle_ids_for(fy_year)
      cycles = DeliveriesCycle.for(self)
      cycles.select! { |c| used_deliveries_cycle_ids.include?(c.id) }
      cycles.each_with_object({}) do |cycle, h|
        range = fiscal_year.beginning_of_year..date
        avg_prices = cycle.deliveries_in(range).map(&:basket_content_avg_prices)
        BasketSize.paid.each do |basket_size|
          prices = avg_prices.map { |ap| ap[basket_size.id.to_s] }.compact
          basket_prices = prices.size * basket_size.price_for(fy_year)
          prices_sum = prices.sum
          h[basket_size.id] ||= {}
          h[basket_size.id][cycle] = (prices_sum - basket_prices).round_to_five_cents
        end
      end
    end
  end

  def basket_content_prices
    bcs = basket_contents.with_unit_price.includes(:depots)
    return {} if bcs.empty?

    BasketSize.paid.map do |basket_size|
      depot_prices = Depot.all.map do |depot|
        [
          depot,
          bcs.sum { |bc| bc.price_for(basket_size, depot) || 0 }.round_to_five_cents
        ]
      end.to_h.select { |_, price| price.positive? } # ignore depot with zero price
      [basket_size, depot_prices]
    end.to_h
  end

  def update_basket_content_avg_prices!
    avg_prices = {}
    basket_content_prices.each do |basket_size, depot_prices|
      prices = depot_prices.flat_map { |depot, price|
        Array(price) * depot.baskets_count_for(self, basket_size)
      }.select(&:positive?) # ignore empty depot
      if prices.any?
        avg_price = prices.sum.fdiv(prices.size)
        avg_prices[basket_size.id] = avg_price.to_f
      end
    end
    update_column(:basket_content_avg_prices, avg_prices)
  end

  private

  def bulk_attributes
    super.map { |h|
      h[:basket_complement_ids] = basket_complement_ids
      h
    }
  end

  def add_subscribed_baskets_complement!(complement)
    BasketsBasketComplement.handle_deliveries_addition!(self, complement)
  end

  def remove_subscribed_baskets_complement!(complement)
    BasketsBasketComplement.handle_deliveries_removal!(self, complement)
  end

  def reset_deliveries_cycle_cache!
    if saved_change_to_date? || destroyed?
      DeliveriesCycle.reset_cache!
    end
  end

  def update_baskets_async
    if saved_change_to_date? || destroyed?
      fiscal_year = Current.acp.fiscal_year_for(date)
      DeliveryBasketsUpdaterJob.perform_later(fiscal_year.year)
    end
  end
end
