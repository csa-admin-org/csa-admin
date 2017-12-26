class Basket < ActiveRecord::Base
  default_scope { joins(:delivery).order('deliveries.date') }

  belongs_to :membership, counter_cache: true
  belongs_to :delivery
  belongs_to :basket_size
  belongs_to :distribution
  has_one :member, through: :membership

  before_save :set_prices

  scope :current_year, -> { joins(:delivery).merge(Delivery.current_year) }
  scope :delivered, -> { joins(:delivery).merge(Delivery.past) }
  scope :between, ->(range) { joins(:delivery).merge(Delivery.between(range)) }
  scope :absent, -> { where(absent: true) }
  scope :not_absent, -> { where(absent: false) }

  def next?
    delivery_id == Delivery.next_coming_id
  end

  def delivered?
    delivery.delivered?
  end

  private

  def set_prices
    self.basket_price = basket_size.price if basket_size_id_changed?
    self.distribution_price = distribution.price if distribution_id_changed?
  end
end
