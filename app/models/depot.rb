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
    Delivery.current_year.count
  end
end
