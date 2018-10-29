require 'rounding'

class Membership < ActiveRecord::Base
  include HasSeasons

  acts_as_paranoid

  belongs_to :member, -> { with_deleted }
  belongs_to :basket_size
  belongs_to :depot
  has_many :baskets, dependent: :destroy
  has_one :next_basket, -> { coming }, class_name: 'Basket'
  has_many :basket_sizes, -> { reorder_by_name }, through: :baskets
  has_many :depots, -> { reorder(:name) }, through: :baskets
  has_many :basket_complements, -> { reorder_by_name }, source: :complements, through: :baskets
  has_many :delivered_baskets, -> { delivered }, class_name: 'Basket'
  has_many :memberships_basket_complements, dependent: :destroy
  has_many :subscribed_basket_complements,
    source: :basket_complement,
    through: :memberships_basket_complements

  accepts_nested_attributes_for :memberships_basket_complements, allow_destroy: true

  before_validation do
    self.basket_price ||= basket_size&.price
    self.depot_price ||= depot&.price
    self.annual_halfday_works ||= basket_quantity * basket_size&.annual_halfday_works
  end

  validates :member, presence: true
  validates :annual_halfday_works, numericality: true
  validates :halfday_works_annual_price, numericality: true
  validates :started_on, :ended_on, presence: true
  validates :basket_quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :basket_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :depot_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :baskets_annual_price_change, numericality: true
  validates :basket_complements_annual_price_change, numericality: true
  validate :good_period_range
  validate :only_one_per_year
  validate :unique_subscribed_basket_complement_id

  before_save :set_renew
  after_save :update_halfday_works
  after_create :create_baskets!
  after_create :clear_member_waiting_info!
  after_update :handle_started_on_change!
  after_update :handle_ended_on_change!
  after_update :handle_subscription_change!
  after_commit :update_member_and_baskets!

  scope :started, -> { where('started_on < ?', Time.current) }
  scope :past, -> { where('ended_on < ?', Time.current) }
  scope :future, -> { where('started_on > ?', Time.current) }
  scope :trial, -> { current.where('remaning_trial_baskets_count > 0') }
  scope :ongoing, -> { current.where(remaning_trial_baskets_count: 0) }
  scope :current, -> { including_date(Date.current) }
  scope :current_or_future, -> { current.or(future) }
  scope :including_date, ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :duration_gt, ->(days) { where("age(ended_on, started_on) > interval '? day'", days) }
  scope :current_year, -> { during_year(Current.fy_year) }
  scope :during_year, ->(year) {
    fy = Current.acp.fiscal_year_for(year)
    where('started_on >= ? AND ended_on <= ?', fy.range.min, fy.range.max)
  }

  def trial?
    remaning_trial_baskets_count.positive?
  end

  def trial_only?
    baskets_count == baskets.trial.count
  end

  def fiscal_year
    @fiscal_year ||= Current.acp.fiscal_year_for(started_on)
  end

  def fy_year
    fiscal_year.year
  end

  def started?
    started_on <= Date.current
  end

  def past?
    ended_on < Date.current
  end

  def current?
    started? && ended_on >= Date.current
  end

  def current_year?
    fy_year == Current.fy_year
  end

  def can_destroy?
    delivered_baskets_count.zero?
  end

  def can_update?
    fy_year >= Current.fy_year
  end

  def memberships_basket_complements_attributes=(*args)
    @tracked_memberships_basket_complements_attributes =
      memberships_basket_complements.map(&:attributes)
    super
  end

  def baskets_annual_price_change=(price)
    super rounded_price(price.to_f)
  end

  def basket_complements_annual_price_change=(price)
    super rounded_price(price.to_f)
  end

  def halfday_works_annual_price=(price)
    super rounded_price(price.to_f)
  end

  def basket_sizes_price
    BasketSize.pluck(:id).sum { |id| basket_size_total_price(id) }
  end

  def basket_size_total_price(basket_size_id)
    rounded_price(
      baskets
        .where(basket_size_id: basket_size_id)
        .sum('quantity * basket_price'))
  end

  def basket_complements_price
    BasketComplement.all.sum { |bc| basket_complement_total_price(bc) }
  end

  def basket_complement_total_price(basket_complement)
    if basket_complement.annual_price_type?
      memberships_basket_complements
        .where(basket_complement: basket_complement)
        .sum('memberships_basket_complements.quantity * memberships_basket_complements.price')
    else
      rounded_price(
        baskets
          .joins(:baskets_basket_complements)
          .where(baskets_basket_complements: { basket_complement: basket_complement })
          .sum('baskets_basket_complements.quantity * baskets_basket_complements.price'))
    end
  end

  def depots_price
    Depot.pluck(:id).sum { |id| depot_total_price(id) }
  end

  def depot_total_price(depot_id)
    rounded_price(
      baskets
        .where(depot_id: depot_id)
        .sum('quantity * depot_price'))
  end

  def price
    basket_sizes_price +
      baskets_annual_price_change +
      basket_complements_price +
      basket_complements_annual_price_change +
      depots_price +
      halfday_works_annual_price
  end

  def first_delivery
    baskets.first&.delivery
  end

  def date_range
    started_on..ended_on
  end

  def renew!
    next_fy = Current.acp.fiscal_year_for(fy_year + 1)
    last_basket = baskets.last
    Membership.create!(
      member: member,
      basket_size_id: last_basket.basket_size_id,
      depot_id: last_basket.depot_id,
      started_on: next_fy.beginning_of_year,
      ended_on: next_fy.end_of_year)
  end

  def basket_size
    return unless basket_size_id
    @basket_size ||= BasketSize.find(basket_size_id)
  end

  def depot
    return unless depot_id
    @depot ||= Depot.find(depot_id)
  end

  def missing_halfday_works
    [halfday_works - recognized_halfday_works, 0].max
  end

  def update_halfday_works!
    deliveries_count = Delivery.during_year(fy_year).count
    percentage =
      if member.salary_basket? || deliveries_count.zero?
        0
      else
        baskets_count / deliveries_count.to_f
      end
    update_column(:halfday_works, (percentage * annual_halfday_works).round)
  end

  def update_recognized_halfday_works!
    participations = member.halfday_participations.not_rejected.during_year(fiscal_year)
    invoices = member.invoices.not_canceled.halfday_participation_type.during_year(fiscal_year)
    update_column(
      :recognized_halfday_works,
      participations.sum(:participants_count) + invoices.sum(:paid_missing_halfday_works))
  end

  def update_baskets_counts!
    update_columns(
      remaning_trial_baskets_count: baskets.coming.trial.count,
      delivered_baskets_count: baskets.delivered.count)
  end

  private

  def set_renew
    if ended_on_changed?
      self.renew = (ended_on >= Current.fy_range.max)
    end
  end

  def update_halfday_works
    if saved_change_to_attribute?(:annual_halfday_works) ||
        saved_change_to_attribute?(:ended_on) ||
        saved_change_to_attribute?(:started_on)

      update_halfday_works!
    end
  end

  def handle_started_on_change!
    if saved_change_to_attribute?(:started_on) && attribute_before_last_save(:started_on)
      if attribute_before_last_save(:started_on) > started_on
        Delivery.between(started_on...attribute_before_last_save(:started_on)).each do |delivery|
          create_basket!(delivery)
        end
      end
      baskets.between(fiscal_year.range.min...started_on).each(&:really_destroy!)
    end
  end

  def handle_ended_on_change!
    if saved_change_to_attribute?(:ended_on) && attribute_before_last_save(:ended_on)
      if attribute_before_last_save(:ended_on) < ended_on
        Delivery.between((attribute_before_last_save(:ended_on) + 1.day)..ended_on).each do |delivery|
          create_basket!(delivery)
        end
      end
      baskets.between((ended_on + 1.day)...fiscal_year.range.max).each(&:really_destroy!)
    end
  end

  def handle_subscription_change!
    tracked_attributes = %w[
      basket_size_id basket_price basket_quantity
      depot_id depot_price
      seasons
    ]
    if (saved_changes.keys & tracked_attributes).any? || memberships_basket_complements_changed?
      deliveries = baskets.between(Time.current..ended_on).includes(:delivery).map(&:delivery)
      baskets.where(delivery_id: deliveries.map(&:id)).each(&:really_destroy!)
      deliveries.each { |delivery| create_basket!(delivery) }
    end
  end

  def memberships_basket_complements_changed?
    @tracked_memberships_basket_complements_attributes &&
      @tracked_memberships_basket_complements_attributes !=
        memberships_basket_complements.map(&:attributes)
  end

  def create_baskets!
    Delivery.between(date_range).each do |delivery|
      create_basket!(delivery)
    end
  end

  def create_basket!(delivery)
    baskets.create!(
      delivery: delivery,
      basket_size_id: basket_size_id,
      basket_price: basket_price,
      quantity: season_quantity(delivery),
      depot_id: depot_id,
      depot_price: depot_price)
  end

  def clear_member_waiting_info!
    member.update!(
      waiting_started_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      waiting_basket_complement_ids: nil)
  end

  def update_member_and_baskets!
    member.reload
    member.update_trial_baskets!
    member.update_absent_baskets!
    member.review_active_state!
    update_baskets_counts!
  end

  def season_quantity(delivery)
    out_of_season_quantity(delivery) || basket_quantity
  end

  def only_one_per_year
    return unless member
    if member.memberships.during_year(fy_year).where.not(id: id).exists?
      errors.add(:member, :taken)
    end
  end

  def good_period_range
    if started_on >= ended_on
      errors.add(:started_on, :before_end)
      errors.add(:ended_on, :after_start)
    end
    if fy_year != Current.acp.fiscal_year_for(ended_on).year
      errors.add(:started_on, :same_fiscal_year)
      errors.add(:ended_on, :same_fiscal_year)
    end
  end

  def unique_subscribed_basket_complement_id
    used_basket_complement_ids = []
    memberships_basket_complements.each do |mbc|
      if mbc.basket_complement_id.in?(used_basket_complement_ids)
        mbc.errors.add(:basket_complement_id, :taken)
        errors.add(:base, :invalid)
      end
      used_basket_complement_ids << mbc.basket_complement_id
    end
  end

  def rounded_price(price)
    return 0 if member.salary_basket?
    price.round_to_five_cents
  end
end
