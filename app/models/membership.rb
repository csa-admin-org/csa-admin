require 'rounding'

class Membership < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :member, -> { with_deleted }
  belongs_to :basket_size
  belongs_to :distribution
  has_many :baskets, dependent: :destroy
  has_many :basket_complements, source: :complements, through: :baskets
  has_many :delivered_baskets, -> { delivered }, class_name: 'Basket'
  has_many :memberships_basket_complements, dependent: :destroy
  has_many :subscribed_basket_complements,
    source: :basket_complement,
    through: :memberships_basket_complements

  accepts_nested_attributes_for :memberships_basket_complements, allow_destroy: true

  before_validation do
    self.basket_price ||= basket_size&.price
    self.distribution_price ||= distribution&.price
    self.annual_halfday_works ||= basket_size&.annual_halfday_works
  end

  validates :member, presence: true
  validates :annual_halfday_works, presence: true
  validates :started_on, :ended_on, presence: true
  validate :good_period_range
  validate :only_one_per_year
  validates :basket_quantity, numericality: { greater_than_or_equal_to: 1 }, presence: true
  validates :basket_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :distribution_price, numericality: { greater_than_or_equal_to: 0 }, presence: true

  before_save :set_renew
  after_save :update_halfday_works
  after_create :create_baskets!
  after_update :handle_started_on_change!
  after_update :handle_ended_on_change!
  after_update :handle_subscription_change!
  after_commit :update_trial_baskets_and_user_state!

  scope :started, -> { where('started_on < ?', Time.current) }
  scope :past, -> { where('ended_on < ?', Time.current) }
  scope :future, -> { where('started_on > ?', Time.current) }
  scope :current, -> { including_date(Date.current) }
  scope :including_date, ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :duration_gt, ->(days) { where("age(ended_on, started_on) > interval '? day'", days) }
  scope :current_year, -> { during_year(Current.fy_year) }
  scope :during_year, ->(year) {
    fy = Current.acp.fiscal_year_for(year)
    where('started_on >= ? AND ended_on <= ?', fy.range.min, fy.range.max)
  }

  def self.billable
    current_year
      .started
      .includes(member: %i[current_membership first_membership current_year_invoices])
      .select(&:billable?)
  end

  def fy_year
    Current.acp.fiscal_year_for(started_on).year
  end

  def billable?
    price.positive?
  end

  def started?
    started_on <= Date.current
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
    BasketComplement.pluck(:id).sum { |id| basket_complement_total_price(id) }
  end

  def basket_complement_total_price(basket_complement_id)
    rounded_price(
      baskets
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { basket_complement_id: basket_complement_id })
        .sum('baskets_basket_complements.quantity * baskets_basket_complements.price'))
  end

  def distributions_price
    Distribution.pluck(:id).sum { |id| distribution_total_price(id) }
  end

  def distribution_total_price(distribution_id)
    rounded_price(
      baskets
        .where(distribution_id: distribution_id)
        .sum('quantity * distribution_price'))
  end

  def halfday_works_annual_price=(price)
    super(price.to_f)
  end

  def halfday_works_price
    rounded_price(halfday_works_annual_price)
  end

  def price
    basket_sizes_price + basket_complements_price + distributions_price + halfday_works_price
  end

  def short_description
    dates = [started_on, ended_on].map { |d| I18n.l(d, format: :number) }
    "Abonnement du #{dates.first} au #{dates.last}"
  end

  def subscribed_basket_description
    case basket_quantity
    when 1 then basket_size.name
    else "#{basket_quantity} x #{basket_size.name}"
    end
  end

  def description
    "#{short_description} (#{baskets_count} #{Delivery.model_name.human(count: baskets_count).downcase})"
  end

  def basket_sizes_description
    "Panier: #{basket_sizes_price_info}"
  end

  def basket_complements_description
    "Compléments: #{basket_complements_price_info}"
  end

  def basket_sizes_price_info
    baskets
      .pluck(:quantity, :basket_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, baskets|
        "#{baskets.sum { |q,_| q }} x #{cur(price)}"
      }.join(' + ')
  end

  def basket_complements_price_info
    baskets
      .joins(:baskets_basket_complements)
      .pluck('baskets_basket_complements.quantity', 'baskets_basket_complements.price')
      .group_by { |_, price| price }
      .sort
      .map { |price, bbcs|
        "#{bbcs.sum { |q,_| q }} x #{cur(price)}"
      }.join(' + ')
  end

  def distributions_price_info
    baskets
      .pluck(:quantity, :distribution_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, baskets|
        "#{baskets.sum { |q,_| q }} x #{cur(price)}"
      }.join(' + ')
  end

  def distribution_description
    if distributions_price.positive?
      "Distribution: #{distributions_price_info}"
    else
      'Distribution: gratuite'
    end
  end

  def halfday_works_description
    diff = annual_halfday_works - HalfdayParticipation::MEMBER_PER_YEAR
    if diff.positive?
      "Réduction pour #{diff} demi-journées de travail supplémentaires"
    elsif diff.negative?
      "#{diff.abs} demi-journées de travail non effectuées"
    elsif halfday_works_price.positive?
      'Demi-journées de travail non effectuées'
    else
      'Demi-journées de travail'
    end
  end

  def first_delivery
    baskets.first&.delivery
  end

  def delivered_baskets_count
    baskets.delivered.count
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
      distribution_id: last_basket.distribution_id,
      started_on: next_fy.beginning_of_year,
      ended_on: next_fy.end_of_year)
  end

  def basket_size
    return unless basket_size_id
    @basket_size ||= BasketSize.find(basket_size_id)
  end

  def distribution
    return unless distribution_id
    @distribution ||= Distribution.find(distribution_id)
  end

  def update_validated_halfday_works!
    validated_participations = member.halfday_participations.validated.during_year(fy_year)
    update_column(:validated_halfday_works, validated_participations.sum(:participants_count))
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
      if attribute_before_last_save(:started_on) < started_on
        baskets.between(attribute_before_last_save(:started_on)...started_on).each(&:really_destroy!)
      end
    end
  end

  def handle_ended_on_change!
    if saved_change_to_attribute?(:ended_on) && attribute_before_last_save(:ended_on)
      if attribute_before_last_save(:ended_on) < ended_on
        Delivery.between((attribute_before_last_save(:ended_on) + 1.day)..ended_on).each do |delivery|
          create_basket!(delivery)
        end
      end
      if attribute_before_last_save(:ended_on) > ended_on
        baskets.between((ended_on + 1.day)...attribute_before_last_save(:ended_on)).each(&:really_destroy!)
      end
    end
  end

  def handle_subscription_change!
    if (saved_changes.keys &
        %w[basket_size_id basket_price basket_quantity distribution_id distribution_price]).any? ||
      memberships_basket_complements_changed?

      deliveries = Delivery.between(Time.current..ended_on)
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
      quantity: basket_quantity,
      distribution_id: distribution_id,
      distribution_price: distribution_price)
  end

  def update_trial_baskets_and_user_state!
    member.reload
    member.update_trial_baskets!
    member.update_absent_baskets!
    member.update_state!
  end

  def only_one_per_year
    return unless member
    if member.memberships.during_year(fy_year).where.not(id: id).exists?
      errors.add(:member, 'seulement un abonnement par an et par membre')
    end
  end

  def good_period_range
    if started_on >= ended_on
      errors.add(:started_on, 'doit être avant la fin')
      errors.add(:ended_on, 'doit être après le début')
    end
    if fy_year != Current.acp.fiscal_year_for(ended_on).year
      errors.add(:started_on, 'doit être dans la même année fiscale que la fin')
      errors.add(:ended_on, 'doit être dans la même année fiscale que le début')
    end
  end

  def rounded_price(price)
    return 0 if member.salary_basket?
    price.round_to_five_cents
  end

  def cur(number)
    precision = number.to_s.split('.').last.size > 2 ? 3 : 2
    ActiveSupport::NumberHelper
      .number_to_currency(number, unit: '', precision: precision).strip
  end
end
