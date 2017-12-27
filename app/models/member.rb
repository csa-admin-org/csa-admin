class Member < ActiveRecord::Base
  include HasState

  BILLING_INTERVALS = %w[annual quarterly].freeze
  SUPPORT_PRICE = 30
  TRIAL_BASKETS = 4

  acts_as_paranoid
  uniquify :token, length: 10

  has_states :pending, :waiting, :trial, :active, :inactive

  belongs_to :validator, class_name: 'Admin'
  belongs_to :waiting_basket_size, class_name: 'BasketSize'
  belongs_to :waiting_distribution, class_name: 'Distribution'
  has_many :absences
  has_many :invoices
  has_many :old_invoices
  has_many :current_year_invoices, -> { during_year(Time.zone.today.year) },
    class_name: 'Invoice'
  has_many :halfday_participations
  has_many :memberships
  has_one :first_membership, -> { order(:started_on) }, class_name: 'Membership'
  has_one :current_membership, -> { current }, class_name: 'Membership'
  has_one :current_year_membership,
    -> { during_year(Time.zone.today.year) },
    class_name: 'Membership'
  has_one :future_membership,
    -> { future },
    class_name: 'Membership'
  has_many :baskets, through: :memberships
  has_many :delivered_baskets,
    through: :memberships,
    source: :delivered_baskets,
    class_name: 'Basket'

  scope :support, -> { inactive.where(support_member: true) }
  scope :with_name, ->(name) {
    where('first_name ILIKE :name OR last_name ILIKE :name', name: "%#{name}%")
  }
  scope :mailable, -> { where.not(emails: nil) }
  scope :with_address, ->(address) {
    where('members.address ILIKE ?', "%#{address}%")
  }
  scope :renew_membership, ->(bool = true) { where(renew_membership: bool) }

  validates :billing_interval,
    presence: true,
    inclusion: { in: BILLING_INTERVALS }
  validates :first_name, :last_name, presence: true
  validates :emails, presence: true,
    if: ->(member) { member.read_attribute(:gribouille) }
  validates :address, :city, :zip, presence: true, unless: :inactive?
  validate :support_member_not_waiting

  before_validation :set_waiting_started_at, on: :create
  before_save :set_state

  def self.gribouille
    all.includes(:current_membership, :future_membership).select(&:gribouille?)
  end

  def self.gribouille_emails
    cache_key = [
      'gribouille_emails',
      maximum(:updated_at),
      Date.today
    ]
    Rails.cache.fetch cache_key do
      gribouille.map(&:emails_array).flatten.uniq.compact
    end
  end

  def self.billable
    includes = %i[
      current_membership
      current_year_membership
      current_year_invoices
    ]
    Member.includes(*includes).all.select(&:billable?)
  end

  def name
    "#{last_name} #{first_name}".strip
  end

  def display_address
    "#{address}, #{city} (#{zip})"
  end

  def display_delivery_address
    "#{final_delivery_address}, #{final_delivery_city} (#{final_delivery_zip})"
  end

  def same_delivery_address?
    display_address == display_delivery_address
  end

  def final_delivery_address
    read_attribute(:delivery_address).presence || address
  end

  def final_delivery_city
    read_attribute(:delivery_city).presence || city
  end

  def final_delivery_zip
    read_attribute(:delivery_zip).presence || zip
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i[with_name with_address]
  end

  def basket_size
    now = Time.current
    (baskets.between(now..now.end_of_year).first || baskets.last)&.basket_size
  end

  def update_state!
    set_state
    save!
  end

  def update_trial_baskets!
    transaction do
      baskets.update_all(trial: false)
      baskets.limit(4).update_all(trial: true)
    end
  end

  def update_absent_baskets!
    transaction do
      baskets.absent.update_all(absent: false)
      absences.each do |absence|
        baskets.between(absence.period).update_all(absent: true)
      end
    end
  end

  def support_member=(bool)
    if bool == '1'
      self.state = INACTIVE_STATE
      self.billing_interval = 'annual'
      self.waiting_started_at = nil
      self.waiting_basket_size_id = nil
      self.waiting_distribution_id = nil
    end
    self[:support_member] = bool
  end

  def validate!(validator)
    invalid_transition(:validate!) unless pending?
    now = Time.current
    update!(
      waiting_started_at: support_member? ? nil : now,
      validated_at: now,
      validator: validator
    )
  end

  def remove_from_waiting_list!
    invalid_transition(:remove_from_waiting_list) unless waiting?
    update!(
      state: INACTIVE_STATE,
      waiting_started_at: nil)
  end

  def put_back_to_waiting_list!
    invalid_transition(:wait!) unless inactive?
    update!(
      state: WAITING_STATE,
      waiting_started_at: Time.current)
  end

  def gribouille?
    gribouille = read_attribute(:gribouille)
    gribouille == true || (
      (waiting? || current_membership || future_membership || support_member?) &&
      gribouille != false
    )
  end

  def absent?(date)
    absences.any? { |absence| absence.period.include?(date) }
  end

  def emails_array
    string_to_a(emails)
  end

  def emails?
    emails_array.present?
  end

  def phones_array
    string_to_a(phones)
  end

  def annual_halfday_works(year = nil)
    @annual_halfday_works ||= begin
      if salary_basket?
        0
      else
        year ||= Time.zone.today.year
        memberships.during_year(year).to_a.sum(&:halfday_works)
      end
    end
  end

  def validated_halfday_works(year = nil)
    @validated_halfday_works ||= begin
      year ||= Time.zone.today.year
      halfday_participations.during_year(year).validated.to_a.sum(&:value)
    end
  end

  def remaining_halfday_works(year = nil)
    [annual_halfday_works(year) - validated_halfday_works(year), 0].max
  end

  def extra_halfday_works(year = nil)
    [annual_halfday_works(year) - validated_halfday_works(year), 0].min.abs
  end

  def to_param
    token
  end

  def can_destroy?
    pending? || waiting?
  end

  alias_method :waiting, :waiting?

  def billable?
    support_member? ||
      (!salary_basket? && current_year_membership && !trial?) ||
      (trial? && !current_membership)
  end

  def support_billable?
    billable? &&
      (support_member? ||
        (active? && delivered_baskets.count > TRIAL_BASKETS))
  end

  private

  def string_to_a(str)
    str.to_s.split(',').each(&:strip!)
  end

  def set_waiting_started_at
    if waiting_basket_size_id? || waiting_distribution_id?
      self.waiting_started_at ||= Time.current
    end
  end

  def set_state
    if !validated_at?
      self.state = PENDING_STATE
    elsif current_membership
      self.waiting_started_at = nil
      if delivered_baskets.count <= TRIAL_BASKETS
        self.state = TRIAL_STATE
      else
        self.state = ACTIVE_STATE
      end
    elsif future_membership
      self.waiting_started_at = nil
      self.state = INACTIVE_STATE
    elsif waiting_started_at?
      self.state = WAITING_STATE
    else
      self.state = INACTIVE_STATE
    end
  end

  def support_member_not_waiting
    if support_member? && waiting?
      errors.add(:support_member, "ne peut pas être sur liste d'attente")
    end
  end
end
