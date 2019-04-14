class Depot < ActiveRecord::Base
  include HasEmails
  include HasPhones
  include HasLanguage

  attr_accessor :delivery_memberships

  belongs_to :responsible_member, class_name: 'Member', optional: true
  has_many :baskets
  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents
  has_and_belongs_to_many :deliveries
  has_and_belongs_to_many :current_deliveries, -> { current_year },
    class_name: 'Delivery',
    after_add: :add_baskets_at!,
    after_remove: :remove_baskets_at!
  has_and_belongs_to_many :future_deliveries, -> { future_year },
    class_name: 'Delivery',
    after_add: :add_baskets_at!,
    after_remove: :remove_baskets_at!

  default_scope { order(:name) }
  scope :visible, -> { where(visible: true) }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true

  def free?
    price.zero?
  end

  def require_delivery_address?
    address.blank?
  end

  def annual_price
    (price * deliveries_count).round_to_five_cents
  end

  def deliveries_count
    @deliveries_count ||= begin
      future_count = future_deliveries.count
      future_count.positive? ? future_count : current_deliveries.count
    end
  end

  private

  def add_baskets_at!(delivery)
    delivery.add_baskets_at!(self)
  end

  def remove_baskets_at!(delivery)
    delivery.remove_baskets_at!(self)
  end
end
