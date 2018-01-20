class Member < ActiveRecord::Base
  include HasState

  BILLING_INTERVALS = %w[annual quarterly].freeze
  SUPPORT_PRICE = 30
  TRIAL_BASKETS = 4

  acts_as_paranoid
  uniquify :token, length: 10

  has_states :pending, :waiting, :trial, :active, :inactive

  belongs_to :validator, class_name: 'Admin', optional: true
  belongs_to :waiting_basket_size, class_name: 'BasketSize', optional: true
  belongs_to :waiting_distribution, class_name: 'Distribution', optional: true
  has_many :absences
  has_many :invoices
  has_many :payments
  has_many :current_year_invoices, -> { current_year }, class_name: 'Invoice'
  has_many :halfday_participations
  has_many :memberships
  has_one :first_membership, -> { order(:started_on) }, class_name: 'Membership'
  has_one :current_membership, -> { current }, class_name: 'Membership'
  has_one :current_year_membership, -> { current_year }, class_name: 'Membership'
  has_one :future_membership, -> { future }, class_name: 'Membership'
  has_many :baskets, through: :memberships
  has_many :delivered_baskets,
    through: :memberships,
    source: :delivered_baskets,
    class_name: 'Basket'

  scope :support, -> { inactive.where(support_member: true) }
  scope :mailable, -> { where.not(emails: nil) }
  scope :with_name, ->(name) { where('members.name ILIKE ?', "%#{name}%") }
  scope :with_address, ->(address) { where('members.address ILIKE ?', "%#{address}%") }
  scope :with_email, ->(email) { where('members.emails ILIKE ?', "%#{email}%") }
  scope :with_phone, ->(phone) { where('members.phones ILIKE ?', "%#{phone}%") }
  scope :gribouille, -> {
    where(state: [WAITING_STATE, TRIAL_STATE, ACTIVE_STATE]).where(gribouille: [nil, true])
      .or(Member.where(support_member: true).where(gribouille: [nil, true]))
      .or(Member.where(gribouille: true))
  }

  validates :billing_interval,
    presence: true,
    inclusion: { in: BILLING_INTERVALS }
  validates :name, presence: true
  validates :emails, presence: true,
    if: ->(member) { member.read_attribute(:gribouille) }
  validates :address, :city, :zip, presence: true, unless: :inactive?
  validate :support_member_not_waiting

  before_validation :set_waiting_started_at, on: :create
  before_save :set_state
  after_save :update_membership_halfday_works

  def gribouille?
    Member.gribouille.where(id: id).exists?
  end

  def self.gribouille_emails
    gribouille.select(:emails).map(&:emails_array).flatten.uniq.compact
  end

  def self.billable
    includes = %i[
      current_membership
      current_year_membership
      current_year_invoices
    ]
    Member.includes(*includes).all.select(&:billable?)
  end

  def name=(name)
    super name.strip
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
    %i[with_name with_address with_email with_phone]
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

  def absent?(date)
    absences.any? { |absence| absence.period.include?(date) }
  end

  def emails_array
    string_to_a(emails)
  end

  def emails?
    emails_array.present?
  end

  def phones=(phones)
    super string_to_a(phones).map { |phone|
      PhonyRails.normalize_number(phone, default_country_code: 'CH')
    }.join(', ')
  end

  def phones_array
    string_to_a(phones)
  end

  def halfday_works(year = nil)
    @annual_halfday_works ||= begin
      year ||= Current.fy_year
      memberships.during_year(year).first&.halfday_works.to_i
    end
  end

  def validated_halfday_works(year = nil)
    @validated_halfday_works ||= begin
      year ||= Current.fy_year
      halfday_participations.during_year(year).validated.sum(&:participants_count)
    end
  end

  def remaining_halfday_works(year = nil)
    [halfday_works(year) - validated_halfday_works(year), 0].max
  end

  def extra_halfday_works(year = nil)
    [halfday_works(year) - validated_halfday_works(year), 0].min.abs
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
      (!salary_basket? && !trial? && current_year_membership.present?) ||
      (trial? && !current_membership) ||
      (trial? && Delivery.next.fy_year > Current.fy_year)
  end

  def support_billable?
    support_member? ||
        (!salary_basket? && current_year_membership && current_year_membership.baskets_count > TRIAL_BASKETS)
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
      if delivered_baskets.count <= TRIAL_BASKETS
        self.state = TRIAL_STATE
      else
        self.state = INACTIVE_STATE
      end
    elsif waiting_started_at?
      self.state = WAITING_STATE
    else
      self.state = INACTIVE_STATE
    end
  end

  def update_membership_halfday_works
    if saved_change_to_attribute?(:salary_basket?)
      current_year_membership&.update_halfday_works!
    end
  end

  def support_member_not_waiting
    if support_member? && waiting?
      errors.add(:support_member, "ne peut pas être sur liste d'attente")
    end
  end
end
