class Basket < ActiveRecord::Base
  acts_as_paranoid

  default_scope { joins(:delivery).order('deliveries.date') }

  delegate :next?, :delivered?, to: :delivery

  belongs_to :membership, counter_cache: true, touch: true
  belongs_to :delivery
  belongs_to :basket_size
  belongs_to :distribution
  has_one :member, through: :membership
  has_many :baskets_basket_complements, dependent: :destroy
  has_many :complements,
    source: :basket_complement,
    through: :baskets_basket_complements

  accepts_nested_attributes_for :baskets_basket_complements, allow_destroy: true

  before_create :add_complements
  before_validation :set_prices

  scope :current_year, -> { joins(:delivery).merge(Delivery.current_year) }
  scope :delivered, -> { joins(:delivery).merge(Delivery.past) }
  scope :coming, -> { joins(:delivery).merge(Delivery.coming) }
  scope :between, ->(range) { joins(:delivery).merge(Delivery.between(range)) }
  scope :absent, -> { where(absent: true) }
  scope :not_absent, -> { where(absent: false) }

  validates :basket_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :distribution_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true

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
    baskets_basket_complements.map(&:description).to_sentence.presence
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

  def remove_complement!(complement)
    complements.delete(complement)
  end

  def blank?
    quantity + baskets_basket_complements.sum(:quantity) == 0
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
          price: mbc.price)
      end
  end

  def set_prices
    self.basket_price ||= basket_size&.price
    self.distribution_price ||= distribution&.price
  end
end
