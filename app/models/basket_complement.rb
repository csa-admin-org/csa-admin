class BasketComplement < ActiveRecord::Base
  include HasDeliveries
  include TranslatedAttributes
  include HasVisibility

  PRICE_TYPES = %w[delivery annual]

  translated_attributes :name

  has_many :baskets_basket_complement, dependent: :destroy
  has_many :memberships_basket_complements, dependent: :destroy
  has_one :shop_product, class_name: 'Shop::Product'

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

  def can_destroy?
    memberships_basket_complements.none? && baskets_basket_complement.none?
  end

  private

  def after_add_delivery!(delivery)
    delivery.add_subscribed_baskets_complement!(self)
  end

  def after_remove_delivery!(delivery)
    delivery.remove_subscribed_baskets_complement!(self)
  end
end
