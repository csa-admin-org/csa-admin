class Basket < ApplicationRecord
  default_scope { joins(:delivery).order('deliveries.date') }

  belongs_to :membership, counter_cache: true, touch: true
  belongs_to :delivery
  belongs_to :basket_size
  belongs_to :depot
  has_one :member, through: :membership
  has_many :baskets_basket_complements, dependent: :destroy
  has_many :complements,
    source: :basket_complement,
    through: :baskets_basket_complements

  accepts_nested_attributes_for :baskets_basket_complements, allow_destroy: true

  before_create :add_complements
  before_validation :set_prices
  after_update { membership.cancel_outdated_invoice! }

  scope :current_year, -> { joins(:delivery).merge(Delivery.current_year) }
  scope :during_year, ->(year) { joins(:delivery).merge(Delivery.during_year(year)) }
  scope :delivered, -> { joins(:delivery).merge(Delivery.past) }
  scope :coming, -> { joins(:delivery).merge(Delivery.coming) }
  scope :between, ->(range) { joins(:delivery).merge(Delivery.between(range)) }
  scope :trial, -> { where(trial: true) }
  scope :not_trial, -> { where(trial: false) }
  scope :absent, -> { where(absent: true) }
  scope :not_absent, -> { where(absent: false) }
  scope :not_empty, -> {
    left_outer_joins(:baskets_basket_complements)
      .where('baskets.quantity > 0 OR baskets_basket_complements.quantity > 0')
  }
  scope :billable, -> {
    unless Current.acp.absences_billed?
      not_absent
    end
  }

  validates :basket_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :depot_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validate :unique_basket_complement_id
  validate :delivery_must_be_in_membership_date_range
  validate :delivery_must_be_in_depot_deliveries

  def description
    [
      basket_description,
      complements_description
    ].compact.join(' + ').presence || '–'
  end

  def basket_description
    case quantity
    when 0 then nil
    when 1 then basket_size.name
    else "#{quantity} x #{basket_size.name}"
    end
  end

  def complements_description
    baskets_basket_complements.map(&:description).compact.to_sentence.presence
  end

  def complements_price
    baskets_basket_complements
      .sum('baskets_basket_complements.quantity * baskets_basket_complements.price')
  end

  def complement?(complement)
    complements.exists?(complement.id)
  end

  def add_complement!(complement, price:, quantity:)
    unless complement?(complement)
      baskets_basket_complements.create!(
        basket_complement: complement,
        quantity: quantity,
        price: price)
    end
  end

  def empty?
    (quantity + baskets_basket_complements.sum(:quantity)).zero?
  end

  def can_update?
    membership.can_update?
  end

  private

  def add_complements
    complement_ids =
      delivery.basket_complement_ids & membership.subscribed_basket_complement_ids
    membership
      .memberships_basket_complements
      .where(basket_complement_id: complement_ids).each do |mbc|
        baskets_basket_complements.build(
          basket_complement_id: mbc.basket_complement_id,
          quantity: mbc.quantity,
          price: mbc.delivery_price)
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

  def delivery_must_be_in_membership_date_range
    if delivery && membership && !delivery.date.in?(membership.date_range)
      errors.add(:delivery, :exclusion)
    end
  end

  def delivery_must_be_in_depot_deliveries
    if delivery && depot && !depot.include_delivery?(delivery)
      errors.add(:depot, :exclusion)
    end
  end
end
