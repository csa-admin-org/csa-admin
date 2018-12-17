class BasketComplement < ActiveRecord::Base
  include TranslatedAttributes

  PRICE_TYPES = %w[delivery annual]

  translated_attributes :name

  has_many :baskets_basket_complement, dependent: :destroy
  has_many :memberships_basket_complements, dependent: :destroy
  has_and_belongs_to_many :deliveries
  has_and_belongs_to_many :current_deliveries, -> { current_year },
    class_name: 'Delivery',
    after_add: :add_subscribed_baskets_complement!,
    after_remove: :remove_subscribed_baskets_complement!
  has_and_belongs_to_many :future_deliveries, -> { future_year },
    class_name: 'Delivery',
    after_add: :add_subscribed_baskets_complement!,
    after_remove: :remove_subscribed_baskets_complement!

  scope :annual_price_type, -> { where(price_type: 'annual') }

  default_scope { order_by_name }

  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :price_type, inclusion: { in: PRICE_TYPES }

  def annual_price_type?
    price_type == 'annual'
  end

  def annual_price
    if annual_price_type?
      price
    else
      (price * deliveries_count).round_to_five_cents
    end
  end

  def delivery_price
    annual_price_type? ? 0 : price
  end

  def display_name; name end

  def deliveries_count
    @deliveries_count ||= begin
      future_count = future_deliveries.count
      future_count.positive? ? future_count : current_deliveries.count
    end
  end

  private

  def add_subscribed_baskets_complement!(delivery)
    delivery.add_subscribed_baskets_complement!(self)
  end

  def remove_subscribed_baskets_complement!(delivery)
    delivery.remove_subscribed_baskets_complement!(self)
  end
end
