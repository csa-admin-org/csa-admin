class BasketSize < ActiveRecord::Base
  include TranslatedAttributes

  translated_attributes :name

  has_many :memberships
  has_many :members, through: :memberships
  has_many :baskets, through: :memberships

  default_scope { order_by_name }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }

  validates :price,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true
  validates :activity_participations_demanded_annualy,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true
  validates :acp_shares_number,
    numericality: { greater_than_or_equal_to: 1 },
    allow_nil: true

  def annual_price
    (price * deliveries_count).round_to_five_cents
  end

  def annual_price=(annual_price)
    self.price = annual_price / deliveries_count.to_f
  end

  def deliveries_count
    future_count = Delivery.future_year.count
    future_count.positive? ? future_count : Delivery.current_year.count
  end

  def display_name; name end

  def can_destroy?
    memberships.none? && baskets.none?
  end
end
