class Delivery < ActiveRecord::Base
  include HasFiscalYearScopes
  include BulkDatesInsert

  default_scope { order(:date) }

  has_many :baskets, dependent: :destroy
  has_many :basket_contents, dependent: :destroy
  has_many :shop_orders, class_name: 'Shop::Order', dependent: :destroy
  has_and_belongs_to_many :basket_complements,
    after_add: :add_subscribed_baskets_complement!,
    after_remove: :remove_subscribed_baskets_complement!
  has_and_belongs_to_many :depots,
    after_add: :add_baskets_at!,
    after_remove: :remove_baskets_at!

  scope :past, -> { where('date < ?', Date.current) }
  scope :coming, -> { where('date >= ?', Date.current) }
  scope :between, ->(range) { where(date: range) }
  scope :shop_open, -> { where(shop_open: true) }

  after_save :update_fiscal_year_numbers
  after_update :handle_date_change!
  after_destroy :update_fiscal_year_numbers
  before_destroy :really_destroy_baskets!

  def self.create_all(count, first_date)
    date = first_date.next_weekday + 2.days # Wed
    count.times do
      create(date: date)
      date = next_date(date)
    end
  end

  def self.next
    coming.order(:date).first
  end

  def self.current
    where('date <= ?', Date.current).order(:date).last
  end

  def self.any_next_year?
    next_year = Current.fiscal_year.year + 1
    Delivery.during_year(next_year).any?
  end

  def delivered?
    date < Time.current
  end

  def display_name(format: :default)
    "#{I18n.l(date, format: format)} ##{number}"
  end

  def add_subscribed_baskets_complement!(complement)
    return unless valid?

    baskets_with_membership_subscribed_to(complement)
      .includes(membership: :memberships_basket_complements)
      .each do |basket|
        mbc = membership_basket_complement_for(basket, complement)
        basket.add_complement!(complement,
          quantity: mbc.season_quantity(self),
          price: mbc.delivery_price)
      end
  end

  def remove_subscribed_baskets_complement!(complement)
    baskets_with_membership_subscribed_to(complement).each do |basket|
      basket.remove_complement!(complement)
    end
  end

  def add_baskets_at!(depot)
    return unless valid?

    Membership
      .including_date(date)
      .where(memberships: { depot_id: depot.id })
      .includes(:baskets)
      .find_each { |membership|
        if membership.baskets.map(&:delivery_id).exclude?(id)
          membership.create_basket!(self)
        end
      }
  end

  def remove_baskets_at!(depot)
    baskets.where(depot_id: depot).destroy_all
  end

  def season
    Current.acp.season_for(date.month)
  end

  def basket_counts
    @basket_counts ||= BasketCounts.new(self, Depot.pluck(:id))
  end

  def shop_closing_at
    return nil unless shop_open

    delay_in_days = Current.acp.shop_delivery_open_delay_in_days.to_i.days
    end_time = Current.acp.shop_delivery_open_last_day_end_time || Tod::TimeOfDay.parse('23:59:59')
    limit = end_time.on(date - delay_in_days)
  end

  def shop_open?
    return false unless shop_open

    !shop_closing_at.past?
  end

  private

  def self.next_date(date)
    fy_year = Current.acp.fiscal_year_for(date).year
    if date >= Date.new(fy_year, 5, 18) && date <= Date.new(fy_year, 12, 21)
      date + 1.week
    else
      date + 2.weeks
    end
  end

  def update_fiscal_year_numbers
    self.class.during_year(fiscal_year).each_with_index do |d, i|
      d.update_column(:number, i + 1)
    end
  end

  def handle_date_change!
    return unless saved_change_to_attribute?(:date)

    baskets.destroy_all
    Membership.including_date(date).find_each { |m| m.create_basket!(self) }
  end

  def membership_basket_complement_for(basket, complement)
    basket
      .membership
      .memberships_basket_complements
      .find { |mbc| mbc.basket_complement_id == complement.id }
  end

  def baskets_with_membership_subscribed_to(complement)
    baskets
      .joins(membership: :memberships_basket_complements)
      .where(memberships_basket_complements: { basket_complement_id: complement.id })
  end

  def really_destroy_baskets!
    baskets.with_deleted.find_each(&:really_destroy!)
  end

  def bulk_attributes
    super.map { |h|
      h[:depot_ids] = depot_ids
      h[:basket_complement_ids] = basket_complement_ids
      h
    }
  end
end
