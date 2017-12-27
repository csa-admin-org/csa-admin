require 'rounding'

class Membership < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :member, -> { with_deleted }
  has_many :baskets
  has_many :delivered_baskets,
    -> { delivered },
    class_name: 'Basket'

  attr_accessor :basket_size_id, :distribution_id

  validates :member, presence: true
  validates :annual_halfday_works, presence: true
  validates :distribution_id, :basket_size_id, presence: true, on: :create
  validates :started_on, :ended_on, presence: true
  validate :good_period_range
  validate :only_one_per_year

  before_create :build_baskets
  before_create :set_annual_halfday_works
  after_update :update_baskets
  after_commit :update_trial_baskets_and_user_state!

  scope :started, -> { where('started_on < ?', Time.zone.now) }
  scope :past, -> { where('ended_on < ?', Time.zone.now) }
  scope :future, -> { where('started_on > ?', Time.zone.now) }
  scope :current, -> { including_date(Time.zone.today) }
  scope :current_year, -> { during_year(Date.today.year) }
  scope :including_date,
    ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :during_year, ->(year) {
    where(
      'started_on >= ? AND ended_on <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }
  scope :duration_gt, ->(days) {
    where("age(ended_on, started_on) > interval '? day'", days)
  }

  def self.billable
    during_year(Time.zone.today.year)
      .started
      .includes(
        member: [:current_membership, :first_membership, :current_year_invoices]
      )
      .select(&:billable?)
  end

  def year
    started_on.year
  end

  def billable?
    price > 0
  end

  def current?
    started_on <= Time.zone.today && ended_on >= Time.zone.today
  end

  def can_destroy?
    delivered_baskets_count.zero?
  end

  def can_update?
    ended_on.year >= Time.current.year
  end

  def halfday_works
    (baskets_count / Delivery.current_year.count.to_f * annual_halfday_works).round
  end

  def basket_total_price
    BasketSize.pluck(:id).sum { |id| baskets_price(id) }
  end

  def baskets_price(basket_size_id)
    rounded_price(baskets.where(basket_size_id: basket_size_id).sum(:basket_price))
  end

  def distribution_total_price
    Distribution.pluck(:id).sum { |id| distributions_price(id) }
  end

  def distributions_price(distribution_id)
    rounded_price(baskets.where(distribution_id: distribution_id).sum(:distribution_price))
  end

  def halfday_works_total_price
    rounded_price(halfday_works_annual_price)
  end

  def price
    basket_total_price + distribution_total_price + halfday_works_total_price
  end

  def short_description
    dates = [started_on, ended_on].map { |d| I18n.l(d, format: :number) }
    "Abonnement du #{dates.first} au #{dates.last}"
  end

  def description
    "#{short_description} (#{baskets_count} #{Delivery.model_name.human(count: baskets_count).downcase})"
  end

  def basket_description
    "Panier: #{basket_total_price_details}"
  end

  def basket_total_price_details
    baskets.group_by(&:basket_price).map { |price, baskets|
      "#{baskets.size} x #{cur(price)}"
    }.join(' + ')
  end

  def distribution_total_price_details
    baskets.group_by(&:distribution_price).map { |price, baskets|
      "#{baskets.size} x #{cur(price)}"
    }.join(' + ')
  end

  def distribution_description
    if distribution_total_price > 0
      "Distribution: #{distribution_total_price_details}"
    else
      "Distribution: gratuit"
    end
  end

  def halfday_works_description
    diff = annual_halfday_works - HalfdayParticipation::MEMBER_PER_YEAR
    if diff.positive?
      "Réduction pour #{diff} demi-journées de travail supplémentaires"
    elsif diff.negative?
      "#{diff.abs} demi-journées de travail non effectuées"
    elsif halfday_works_total_price.positive?
      "Demi-journées de travail non effectuées"
    else
      "Demi-journées de travail"
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
    renew_year = Time.zone.today.next_year
    last_basket = baskets.last
    Membership.create!(
      member: member,
      basket_size_id: last_basket.basket_size_id,
      distribution_id: last_basket.distribution_id,
      started_on: renew_year.beginning_of_year,
      ended_on: renew_year.end_of_year)
  end

  def basket_size
    return unless basket_size_id
    @basket_size ||= BasketSize.find(basket_size_id)
  end

  def distribution
    return unless distribution_id
    @distribution ||= Distribution.find(distribution_id)
  end

  private

  def set_annual_halfday_works
    self[:annual_halfday_works] = basket_size.annual_halfday_works
  end

  def build_baskets
    Delivery.between(date_range).each do |delivery|
      baskets.build(
        delivery: delivery,
        basket_size_id: basket_size_id,
        distribution_id: distribution_id)
    end
  end

  def update_baskets
    if basket_size_id || distribution_id
      baskets.between(Time.current..ended_on).each do |basket|
        basket.basket_size_id = basket_size_id if basket_size_id
        basket.distribution_id = distribution_id if distribution_id
        basket.save!
      end
    end
    if saved_change_to_attribute?(:started_on) || saved_change_to_attribute?(:ended_on)
      (baskets - baskets.between(started_on..ended_on)).each(&:destroy)
    end
  end

  def update_trial_baskets_and_user_state!
    if saved_change_to_attribute?(:started_on) || saved_change_to_attribute?(:ended_on)
      member.reload
      member.update_trial_baskets!
      member.update_absent_baskets!
      member.update_state!
    end
  end

  def only_one_per_year
    return unless member
    if member.memberships.during_year(started_on.year).where.not(id: id).exists?
      errors.add(:base, 'seulement un abonnement par an et par membre')
    end
  end

  def good_period_range
    if started_on >= ended_on
      errors.add(:started_on, 'doit être avant la fin')
      errors.add(:ended_on, 'doit être après le début')
    end
    if ended_on.year != started_on.year
      errors.add(:started_on, 'doit être dans la même année que la fin')
      errors.add(:ended_on, 'doit être dans la même année que le début')
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
