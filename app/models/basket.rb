class Basket < ActiveRecord::Base
  acts_as_paranoid

  default_scope { joins(:delivery).order('deliveries.date') }

  delegate :next?, :delivered?, to: :delivery

  belongs_to :membership, counter_cache: true, touch: true
  belongs_to :delivery
  belongs_to :basket_size
  belongs_to :distribution
  has_one :member, through: :membership
  has_many :baskets_basket_complements
  has_many :complements,
    source: :basket_complement,
    through: :baskets_basket_complements

  before_create :add_complements
  before_save :set_prices

  scope :current_year, -> { joins(:delivery).merge(Delivery.current_year) }
  scope :delivered, -> { joins(:delivery).merge(Delivery.past) }
  scope :coming, -> { joins(:delivery).merge(Delivery.coming) }
  scope :between, ->(range) { joins(:delivery).merge(Delivery.between(range)) }
  scope :absent, -> { where(absent: true) }
  scope :not_absent, -> { where(absent: false) }

  def description
    txt = basket_size.name
    if complements.any?
      txt += ' + '
      txt += complements.map(&:name).to_sentence
    end
    txt
  end

  def complements_price
    baskets_basket_complements.sum(:price)
  end

  def complement?(complement)
    complements.exists?(complement.id)
  end

  def add_complement!(complement)
    unless complement?(complement)
      complements.push(complement)
    end
  end

  def remove_complement!(complement)
    complements.delete(complement)
  end

  private

  def add_complements
    self.complement_ids =
      delivery.basket_complement_ids & membership.subscribed_basket_complement_ids
  end

  def set_prices
    self.basket_price = basket_size.price if basket_size_id_changed?
    self.distribution_price = distribution.price if distribution_id_changed?
  end
end
