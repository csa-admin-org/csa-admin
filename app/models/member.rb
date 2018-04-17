class Member < ActiveRecord::Base
  include HasState
  include HasEmails
  include HasPhones

  BILLING_INTERVALS = %w[annual quarterly].freeze

  acts_as_paranoid
  uniquify :token, length: 10

  has_states :pending, :waiting, :trial, :active, :inactive

  belongs_to :validator, class_name: 'Admin', optional: true
  belongs_to :waiting_basket_size, class_name: 'BasketSize', optional: true
  belongs_to :waiting_distribution, class_name: 'Distribution', optional: true
  has_and_belongs_to_many :waiting_basket_complements, class_name: 'BasketComplement'
  has_many :absences
  has_many :invoices
  has_many :payments
  has_many :current_year_invoices, -> { current_year }, class_name: 'Invoice'
  has_many :halfday_participations
  has_many :memberships
  has_one :first_membership, -> { order(:started_on) }, class_name: 'Membership'
  has_one :current_membership, -> { current }, class_name: 'Membership'
  has_one :future_membership, -> { future }, class_name: 'Membership'
  has_one :current_or_future_membership, -> { current_or_future }, class_name: 'Membership'
  has_one :current_year_membership, -> { current_year }, class_name: 'Membership'
  has_many :baskets, through: :memberships
  has_one :next_basket, through: :current_or_future_membership
  has_many :delivered_baskets,
    through: :memberships,
    source: :delivered_baskets,
    class_name: 'Basket'

  scope :billable, -> { where(state: [ACTIVE_STATE, INACTIVE_STATE]) }
  scope :support, -> { inactive.where(support_member: true) }
  scope :with_name, ->(name) { where('members.name ILIKE ?', "%#{name}%") }
  scope :with_address, ->(address) { where('members.address ILIKE ?', "%#{address}%") }
  scope :gribouille, -> {
    where(state: [WAITING_STATE, TRIAL_STATE, ACTIVE_STATE])
      .where(gribouille: [nil, true])
      .or(Member.where(support_member: true).where(gribouille: [nil, true]))
      .or(Member.where(gribouille: true))
  }

  validates :billing_year_division,
    presence: true,
    inclusion: { in: ->(_) { Current.acp.billing_year_divisions } }
  validates :name, presence: true
  validates :emails, presence: true,
    if: ->(member) { member.read_attribute(:gribouille) }
  validates :address, :city, :zip, presence: true, unless: :inactive?
  validate :support_member_not_waiting
  validates :support_price, numericality: { greater_than_or_equal_to: 0 }, presence: true

  before_validation :set_initial_support_price, on: :create
  before_validation :set_initial_waiting_started_at, on: :create
  before_save :set_state, :set_support_member
  after_save :update_membership_halfday_works

  def gribouille?
    Member.gribouille.where(id: id).exists?
  end

  def self.gribouille_emails
    gribouille.select(:emails).map(&:emails_array).flatten.uniq.compact
  end

  def billable?
    active? || inactive?
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

  def page_url
    [Current.acp.email_default_host, token].join('/')
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
      baskets.limit(Current.acp.trial_basket_count).update_all(trial: true)
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

  def validate!(validator)
    invalid_transition(:validate!) unless pending?
    update!(
      validated_at: Time.current,
      validator: validator)
  end

  def remove_from_waiting_list!
    invalid_transition(:remove_from_waiting_list) unless waiting?
    update!(
      support_member: false,
      waiting_started_at: nil)
  end

  def put_back_to_waiting_list!
    invalid_transition(:wait!) unless inactive?
    update!(
      support_member: false,
      waiting_started_at: Time.current)
  end

  def send_welcome_email
    return unless active? && emails?
    return if welcome_email_sent_at?

    Email.deliver_now(:member_welcome, self)
    touch(:welcome_email_sent_at)
  end

  def absent?(date)
    absences.any? { |absence| absence.period.include?(date) }
  end

  def membership(year = nil)
    year ||= Current.fiscal_year
    memberships.during_year(year).first
  end

  def to_param
    token
  end

  def language; 'fr' end

  def can_destroy?
    pending? || waiting?
  end

  def invoices_amount
    invoices.not_canceled.sum(:amount)
  end

  def payments_amount
    payments.sum(:amount)
  end

  def credit_amount
    [payments_amount - invoices_amount, 0].max
  end

  alias_method :waiting, :waiting?

  private

  def set_initial_support_price
    self.support_price ||= Current.acp.support_price
  end

  def set_initial_waiting_started_at
    if waiting_basket_size_id? || waiting_distribution_id?
      self.waiting_started_at ||= Time.current
    end
  end

  def set_state
    if !validated_at?
      self.state = PENDING_STATE
    elsif current_membership
      if baskets_in_trial?
        self.state = TRIAL_STATE
      else
        self.state = ACTIVE_STATE
      end
    elsif future_membership
      if baskets_in_trial?
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

  def set_support_member
    if waiting? || trial? || active? || future_membership
      self.support_member = false
    end
  end

  def baskets_in_trial?
    Current.acp.trial_basket_count.positive? &&
      delivered_baskets.count <= Current.acp.trial_basket_count
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
