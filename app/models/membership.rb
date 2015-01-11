class Membership < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :member, validate: true
  belongs_to :billing_member, class_name: 'Member', validate: true
  belongs_to :basket
  belongs_to :distribution

  validates :member, :distribution, :basket, presence: true
  validates :started_on, :ended_on, presence: true
  validate :withing_basket_year
  validate :good_period_range
  validate :only_one_alongs_the_year
  validate :will_be_changed_at_good_date

  before_save :build_new_membership
  after_save :save_new_membership

  scope :past, -> { where('ended_on < ?', Time.now) }
  scope :future, -> { where('started_on > ?', Time.now) }
  scope :current, -> { including_date(Date.today) }
  scope :including_date,
    ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :during_year, ->(year) {
    where(
      'started_on >= ? AND ended_on <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }

  attr_accessor :will_be_changed_at

  def will_be_changed_at=(date)
    if date.present?
      @will_be_changed_at = Date.parse(date)
    end
  end

  def billing_member
    (billing_member_id && Member.find(billing_member_id)) || member
  end

  def current?
    started_on <= Date.today && ended_on >= Date.today
  end

  def can_destroy?
    deliveries_received_count == 0
  end

  def can_update?
    current?
  end

  def annual_price
    read_attribute(:annual_price) || basket.try(:annual_price)
  end

  def annual_halfday_works
    if billing_member.try(:salary_basket?)
      0
    else
      read_attribute(:annual_halfday_works) || basket.try(:annual_halfday_works)
    end
  end

  def basket_price
    annual_price.to_f / 40.0
  end

  def distribution_basket_price
    read_attribute(:distribution_basket_price) || distribution.try(:basket_price)
  end

  def halfday_works_basket_price
    diff = basket.annual_halfday_works - annual_halfday_works
    diff > 0 ? diff * HalfdayWork::PRICE/40.0 : 0
  end

  def total_basket_price
    if billing_member.try(:salary_basket?)
      0
    else
      basket_price + distribution_basket_price.to_f + halfday_works_basket_price.to_f
    end
  end

  def deliveries_received_count
    Delivery.between(started_on..Date.today).count
  end

  def deliveries_count
    Delivery.between(started_on..ended_on).count
  end

  def date_range
    started_on..ended_on
  end

  private

  def build_new_membership
    if @will_be_changed_at
      attrs = attributes.except('id').merge('started_on' => @will_be_changed_at)
      @new_membership = Membership.new(attrs)
      reload
      self.ended_on = @will_be_changed_at - 1.day
    end
  end

  def save_new_membership
    @new_membership && @new_membership.save!
  end

  def only_one_alongs_the_year
    Membership.where(member: member).where.not(id: id).each do |membership|
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

  def will_be_changed_at_good_date
    if @will_be_changed_at && (
         @will_be_changed_at < Date.today ||
         @will_be_changed_at <= started_on ||
         @will_be_changed_at >= ended_on
       )
      errors.add(:will_be_changed_at, :invalid)
    end
  end
end
