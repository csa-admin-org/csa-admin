class Membership < ActiveRecord::Base
  belongs_to :member
  belongs_to :billing_member, class_name: 'Member'
  belongs_to :basket
  belongs_to :distribution

  validates :member, :distribution, :basket, presence: true
  validates :started_on, :ended_on, presence: true
  validate :withing_basket_year
  validate :good_period_range
  validate :only_one_alongs_the_year

  scope :old, -> { where('ended_on < ?', Time.now) }
  scope :current, -> { with_date(Date.today_2015) }
  scope :active, -> { joins(:member).merge(Member.active) }
  scope :with_date,
    ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :during_year, ->(year) {
    where(
      'started_on >= ? AND ended_on <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }

  def billing_member
    id = billing_member_id || member_id
    id && Member.find(id)
  end

  def current?
    started_on <= Date.today_2015 && ended_on >= Date.today_2015
  end

  def can_destroy?
    deliveries_done_since(Date.today) == 0
  end

  def can_update?
    current?
  end

  def annual_price
    read_attribute(:annual_price) || basket.try(:annual_price)
  end

  def annual_halfday_works
    read_attribute(:annual_halfday_works) || basket.try(:annual_halfday_works)
  end

  def basket_price
    price = annual_price.to_i / 40.0
    price += distribution.basket_price if annual_price.to_i > 0
    price
  end

  def deliveries_done_since(date)
    Delivery.between(started_on..date).count
  end

  def deliveries_count
    Delivery.between(started_on..ended_on).count
  end

  def date_range
    started_on..ended_on
  end

  private

  def only_one_alongs_the_year
    Membership.where(member: member).each do |membership|
      if membership.date_range.include?(started_on)
        errors.add(:started_on, 'déjà inclus dans un abonnement existant')
      end
      if membership.date_range.include?(ended_on)
        errors.add(:ended_on, 'déjà inclus dans un abonnement existant')
      end
      break
    end
  end

  def withing_basket_year
    if basket.year != started_on.year
      errors.add(:started_on, 'doit être durant la même année que le panier')
    end
    if basket.year != ended_on.year
      errors.add(:ended_on, 'doit être durant la même année que le panier')
    end
  end

  def good_period_range
    if started_on >= ended_on
      errors.add(:started_on, 'doit être avant la fin')
      errors.add(:ended_on, 'doit être après le début')
    end
  end
end
