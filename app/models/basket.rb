class Basket < ApplicationRecord
  include HasDescription
  include HasState

  has_states :normal, :absent, :trial

  default_scope { joins(:delivery).order("deliveries.date") }

  belongs_to :membership, counter_cache: true, touch: true
  belongs_to :delivery
  belongs_to :basket_size
  belongs_to :depot
  belongs_to :absence, optional: true
  has_one :member, through: :membership
  has_many :baskets_basket_complements, dependent: :destroy
  has_many :complements,
    source: :basket_complement,
    through: :baskets_basket_complements

  accepts_nested_attributes_for :baskets_basket_complements, allow_destroy: true

  before_create :add_complements
  before_validation :set_prices
  before_save :set_calculated_price_extra

  scope :current_year, -> { joins(:delivery).merge(Delivery.current_year) }
  scope :during_year, ->(year) { joins(:delivery).merge(Delivery.during_year(year)) }
  scope :past, -> { joins(:delivery).merge(Delivery.past) }
  scope :coming, -> { joins(:delivery).merge(Delivery.coming) }
  scope :between, ->(range) { joins(:delivery).merge(Delivery.between(range)) }
  scope :billable, -> { where(billable: true) }
  scope :deliverable, -> { active.filled }
  scope :active, -> { where(state: %i[normal trial]) }
  scope :filled, -> {
    left_outer_joins(:baskets_basket_complements)
      .where("baskets.quantity > 0 OR baskets_basket_complements.quantity > 0")
  }

  validates :basket_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :price_extra, numericality: true, presence: true
  validates :depot_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validate :unique_basket_complement_id
  validate :delivery_must_be_in_membership_period

  def self.complement_count(complement)
    joins(:baskets_basket_complements)
      .where(baskets_basket_complements: { basket_complement_id: complement.id })
      .sum("baskets_basket_complements.quantity")
  end

  def description(public_name: false)
    [
      basket_description(public_name: public_name),
      complements_description(public_name: public_name)
    ].compact.join(" + ").presence || "–"
  end

  def basket_description(public_name: false)
    describe(basket_size, quantity, public_name: public_name)
  end

  def complements_description(public_name: false)
    baskets_basket_complements
      .joins(:basket_complement)
      .merge(BasketComplement.order_by_name)
      .map { |bc| bc.description(public_name: public_name) }
      .compact.to_sentence.presence
  end

  def complements_price
    baskets_basket_complements.sum { |bbc| bbc.quantity * bbc.price }
  end

  def empty?
    (quantity + baskets_basket_complements.sum(:quantity)).zero?
  end

  def can_update?
    membership.can_update? && billable?
  end

  def can_member_update?
    return false if absent?
    return false unless Current.acp.membership_depot_update_allowed? ||
                        Current.acp.membership_complements_update_allowed?
    return false unless Current.acp.basket_update_limit_in_days

    delivery.date >= Current.acp.basket_update_limit_in_days.days.from_now
  end

  def member_update!(params)
    raise "update not allowed" unless can_member_update?

    if params.key?(:depot_id)
      self.depot_price = nil
    end
    update!(params)
  end

  private

  def add_complements
    complement_ids =
      delivery.basket_complement_ids & membership.subscribed_basket_complement_ids
    membership
      .memberships_basket_complements
      .includes(:delivery_cycle)
      .where(basket_complement_id: complement_ids).each do |mbc|
        next if mbc.delivery_cycle && !mbc.delivery_cycle.include_delivery?(delivery)

        baskets_basket_complements.build(mbc.attributes.slice(*%w[
          basket_complement_id
          quantity
          price
        ]))
      end
  end

  def set_prices
    self.basket_price ||= basket_size&.price
    self.depot_price ||= depot&.price
  end

  def unique_basket_complement_id
    used_basket_complement_ids = []
    baskets_basket_complements.each do |bbc|
      if bbc.basket_complement_id.in?(used_basket_complement_ids)
        bbc.errors.add(:basket_complement_id, :taken)
        errors.add(:base, :invalid)
      end
      used_basket_complement_ids << bbc.basket_complement_id
    end
  end

  def delivery_must_be_in_membership_period
    if delivery && membership && !delivery.date.in?(membership.period)
      errors.add(:delivery, :exclusion)
    end
  end

  def set_calculated_price_extra
    self.calculated_price_extra = calculate_price_extra
  end

  def calculate_price_extra
    return 0 unless Current.acp.feature?("basket_price_extra")
    return 0 if basket_price.zero? && complements_price.zero?

    Current.acp.calculate_basket_price_extra(
      price_extra,
      basket_price,
      basket_size_id,
      complements_price,
      Current.acp.deliveries_count(membership.fy_year))
  end
end
