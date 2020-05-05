class Member < ActiveRecord::Base
  include HasState
  include HasEmails
  include HasPhones
  include HasLanguage
  include HasSessions

  BILLING_INTERVALS = %w[annual quarterly].freeze

  acts_as_paranoid

  attr_accessor :public_create
  attribute :annual_fee, :decimal, default: -> { Current.acp.annual_fee }

  has_states :pending, :waiting, :active, :support, :inactive

  belongs_to :validator, class_name: 'Admin', optional: true
  belongs_to :waiting_basket_size, class_name: 'BasketSize', optional: true
  belongs_to :waiting_depot, class_name: 'Depot', optional: true
  has_and_belongs_to_many :waiting_basket_complements, class_name: 'BasketComplement'
  has_many :absences
  has_many :invoices
  has_many :payments
  has_many :current_year_invoices, -> { current_year }, class_name: 'Invoice'
  has_many :activity_participations
  has_many :memberships
  has_one :first_membership, -> { order(:started_on) }, class_name: 'Membership'
  has_one :current_membership, -> { current }, class_name: 'Membership'
  has_one :future_membership, -> { future }, class_name: 'Membership'
  has_one :current_or_future_membership, -> { current_or_future }, class_name: 'Membership'
  has_one :last_membership, -> { order(started_on: :desc) }, class_name: 'Membership'
  has_one :current_year_membership, -> { current_year }, class_name: 'Membership'
  has_many :baskets, through: :memberships
  has_one :next_basket, through: :current_or_future_membership
  has_many :delivered_baskets,
    through: :memberships,
    source: :delivered_baskets,
    class_name: 'Basket'
  has_many :group_buying_orders, class_name: 'GroupBuying::Order'

  scope :trial, -> { joins(:current_membership).merge(Membership.trial) }
  scope :with_name, ->(name) { where('members.name ILIKE ?', "%#{name}%") }
  scope :with_address, ->(address) { where('members.address ILIKE ?', "%#{address}%") }

  before_validation :set_default_billing_year_division

  validates_acceptance_of :terms_of_service
  validates :billing_year_division,
    presence: true,
    inclusion: { in: proc { Current.acp.billing_year_divisions } }
  validates :name, presence: true
  validates :emails, presence: true, if: :public_create
  validates :address, :city, :zip, presence: true, on: :create, unless: :inactive?
  validates :waiting_basket_size, inclusion: { in: proc { BasketSize.all }, allow_nil: true }, on: :create
  validates :waiting_depot, inclusion: { in: proc { Depot.all } }, if: :waiting_basket_size, on: :create
  validates :annual_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :existing_acp_shares_number, numericality: { greater_than_or_equal_to: 0 }
  validate :email_must_be_unique

  before_save :handle_annual_fee_change
  after_save :update_membership_if_salary_basket_changed
  after_create_commit :notify_new_inscription_to_admins, if: :public_create

  def newsletter?
    (
      state.in?([WAITING_STATE, ACTIVE_STATE, SUPPORT_STATE]) &&
        newsletter.in?([true, nil])
    ) || newsletter == true
  end

  def billable?
    active? || support? || current_year_membership
  end

  def name=(name)
    super name.strip
  end

  def display_address
    address.present? ? "#{address}, #{city} (#{zip})" : '–'
  end

  def display_delivery_address
    if final_delivery_address.present?
      "#{final_delivery_address}, #{final_delivery_city} (#{final_delivery_zip})"
    else
      '–'
    end
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

  def update_trial_baskets!
    transaction do
      baskets.update_all(trial: false)
      baskets.limit(Current.acp.trial_basket_count).update_all(trial: true)
    end
  end

  def validate!(validator)
    invalid_transition(:validate!) unless pending?

    if waiting_basket_size_id? || waiting_depot_id?
      self.waiting_started_at ||= Time.current
      self.state = WAITING_STATE
    elsif annual_fee
      self.state = SUPPORT_STATE
    else
      self.state = INACTIVE_STATE
    end
    self.validated_at = Time.current
    self.validator = validator
    save!
  end

  def wait!
    invalid_transition(:wait!) unless can_wait?

    self.state = WAITING_STATE
    self.waiting_started_at = Time.current
    self.annual_fee ||= Current.acp.annual_fee
    save!
  end

  def review_active_state!
    if current_or_future_membership
      activate! unless active?
    elsif active?
      deactivate!
    end
  end

  def activate!
    invalid_transition(:activate!) unless current_or_future_membership
    return if active?

    self.state = ACTIVE_STATE
    self.annual_fee ||= Current.acp.annual_fee
    save!
  end

  def deactivate!
    invalid_transition(:deactivate!) unless can_deactivate?

    state =
      if acp_shares_number.positive?
        SUPPORT_STATE
      else
        INACTIVE_STATE
      end

    update!(
      state: state,
      waiting_started_at: nil,
      annual_fee: nil)
  end

  def can_wait?
    support? || inactive?
  end

  def can_deactivate?
    !inactive? && (waiting? || support? || !current_or_future_membership)
  end

  def send_welcome_email
    return unless active? && emails?
    return if welcome_email_sent_at?

    Email.deliver_now(:member_welcome, self)
    touch(:welcome_email_sent_at)
  end

  def absent?(date)
    absences.any? { |absence| absence.period.include?(date.to_date) }
  end

  def membership(year = nil)
    year ||= Current.fiscal_year
    memberships.during_year(year).first
  end

  def can_destroy?
    pending?
  end

  def invoices_amount
    @invoices_amount ||= invoices.not_canceled.sum(:amount)
  end

  def payments_amount
    @payments_amount ||= payments.sum(:amount)
  end

  def balance_amount
    payments_amount - invoices_amount
  end

  def credit_amount
    [balance_amount, 0].max
  end

  def acp_shares_number
    existing_acp_shares_number + invoices.not_canceled.acp_share.sum(:acp_shares_number)
  end

  def handle_acp_shares_change!
    if acp_shares_number.positive?
      update_column(:state, SUPPORT_STATE) if inactive?
    elsif support?
      update_column(:state, INACTIVE_STATE)
    end
  end

  private

  def set_default_billing_year_division
    self[:billing_year_division] ||=
      Current.acp.billing_year_divisions.first
  end

  def email_must_be_unique
    emails_array.each do |email|
      if Member.where.not(id: id).including_email(email).exists?
        errors.add(:emails, :taken)
        break
      end
    end
  end

  def public_create_and_not_support?
    public_create && !support?
  end

  def baskets_in_trial?
    Current.acp.trial_basket_count.positive? &&
      delivered_baskets.count <= Current.acp.trial_basket_count
  end

  def update_membership_if_salary_basket_changed
    return unless saved_change_to_attribute?(:salary_basket)

    [current_year_membership, future_membership].compact.each do |m|
      m.update_activity_participations_demanded!
      m.touch
    end
  end

  def handle_annual_fee_change
    return unless Current.acp.annual_fee?

    if annual_fee
      self.state = SUPPORT_STATE if inactive?
    elsif support?
      self.state = INACTIVE_STATE
    end
  end

  def notify_new_inscription_to_admins
    Admin.notification('new_inscription').find_each do |admin|
      Email.deliver_later(:member_new, admin, self)
    end
  end
end
