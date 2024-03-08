class Member < ApplicationRecord
  include HasState
  include HasEmails
  include HasPhones
  include HasLanguage
  include HasSessions
  include HasIBAN
  include Auditable

  BILLING_INTERVALS = %w[annual quarterly].freeze

  # Temporary attributes for Delivery XLSX worksheet
  attr_accessor :basket, :shop_order

  attr_accessor :public_create
  attribute :annual_fee, :decimal, default: -> { Current.acp.annual_fee }
  attribute :language, :string, default: -> { Current.acp.languages.first }

  audited_attributes \
    :state, :name, :address, :zip, :city, :country_code, :emails, :phones, :contact_sharing, \
    :iban, :sepa_mandate_id, :sepa_mandate_signed_on

  has_states :pending, :waiting, :active, :support, :inactive

  belongs_to :validator, class_name: "Admin", optional: true
  belongs_to :waiting_basket_size, class_name: "BasketSize", optional: true
  belongs_to :waiting_depot, class_name: "Depot", optional: true
  belongs_to :waiting_delivery_cycle, class_name: "DeliveryCycle", optional: true
  has_and_belongs_to_many :waiting_alternative_depots,
    class_name: "Depot",
    join_table: "members_waiting_alternative_depots",
    optional: true
  belongs_to :shop_depot, class_name: "Depot", optional: true
  has_many :absences, dependent: :destroy
  has_many :invoices
  has_many :payments
  has_many :current_year_invoices, -> { current_year }, class_name: "Invoice"
  has_many :activity_participations, dependent: :destroy
  has_many :memberships
  has_one :first_membership, -> { order(:started_on) }, class_name: "Membership"
  has_one :current_membership, -> { current }, class_name: "Membership"
  has_one :future_membership, -> { future }, class_name: "Membership"
  has_one :current_or_future_membership, -> { current_or_future }, class_name: "Membership"
  has_one :last_membership, -> { order(started_on: :desc) }, class_name: "Membership"
  has_one :current_year_membership, -> { current_year }, class_name: "Membership"
  has_many :baskets, through: :memberships
  has_one :next_basket, through: :current_or_future_membership
  has_one :next_delivery, through: :current_or_future_membership
  has_many :shop_orders, class_name: "Shop::Order"
  has_many :members_basket_complements, dependent: :destroy
  has_many :waiting_basket_complements,
    source: :basket_complement,
    through: :members_basket_complements
  has_many :newsletter_deliveries, class_name: "Newsletter::Delivery", dependent: :destroy

  accepts_nested_attributes_for :members_basket_complements, allow_destroy: true

  scope :not_pending, -> { where.not(state: "pending") }
  scope :not_inactive, -> { where.not(state: "inactive") }
  scope :trial, -> { joins(:current_membership).merge(Membership.trial) }
  scope :sharing_contact, -> { where(contact_sharing: true) }
  scope :with_name, ->(name) { where("members.name ILIKE ?", "%#{name}%") }
  scope :with_address, ->(address) { where("members.address ILIKE ?", "%#{address}%") }
  scope :no_salary_basket, -> { where(salary_basket: false) }
  scope :with_waiting_depots_eq, ->(depot_id) {
    left_joins(:members_waiting_alternative_depots).where(<<-SQL, depot_id: depot_id).distinct
      members.waiting_depot_id = :depot_id OR
      members_waiting_alternative_depots.depot_id = :depot_id
    SQL
  }

  after_initialize :set_defaults, unless: :persisted?
  before_validation :set_default_billing_year_division
  before_validation :set_default_waiting_delivery_cycle

  validates_acceptance_of :terms_of_service
  validates :billing_year_division,
    inclusion: { in: proc { Current.acp.billing_year_divisions } },
    on: :create
  validates :billing_year_division,
    presence: true,
    inclusion: { in: ACP.billing_year_divisions }
  validates :country_code,
    inclusion: { in: ISO3166::Country.all.map(&:alpha2), allow_blank: true }
  validates :name, presence: true
  validates :emails, presence: true, if: :public_create
  validates :phones, presence: true, if: :public_create
  validates :profession, presence: true,
    if: -> { public_create && Current.acp.member_profession_form_mode == "required" }
  validates :come_from, presence: true,
    if: -> { public_create && Current.acp.member_come_from_form_mode == "required" }
  validates :address, :city, :zip, :country_code, presence: true, unless: :inactive?
  validates :waiting_basket_size, inclusion: { in: proc { BasketSize.all }, allow_nil: true }, on: :create
  validates :waiting_basket_size_id, presence: true, if: :waiting_depot, on: :create
  validates :waiting_activity_participations_demanded_annually, numericality: true, allow_nil: true
  validates :waiting_basket_price_extra, presence: true, if: -> { Current.acp.feature?("basket_price_extra") && waiting_depot }, on: :create
  validates :waiting_depot, inclusion: { in: proc { Depot.all }, allow_nil: true }, on: :create
  validates :waiting_depot_id, presence: true, if: :waiting_basket_size, on: :create
  validates :shop_depot, inclusion: { in: proc { Depot.all }, allow_nil: true }
  validates :annual_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :email_must_be_unique
  validate :unique_waiting_basket_complement_id
  validates :existing_acp_shares_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :required_acp_shares_number, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :desired_acp_shares_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :desired_acp_shares_number,
    numericality: { greater_than_or_equal_to: 1 },
    if: -> { public_create && Current.acp.share? }
  validates :billing_email, format: { with: ACP::EMAIL_REGEXP, allow_nil: true }
  validates :iban, presence: true, if: :sepa_mandate_id?
  validates :iban, format: -> { Billing.iban_format(Current.acp.country_code) }, allow_nil: :true
  validates :sepa_mandate_id, presence: true, if: :sepa_mandate_signed_on?
  validates :sepa_mandate_signed_on, presence: true, if: :sepa_mandate_id?

  before_save :handle_annual_fee_change
  after_save :update_membership_if_salary_basket_changed
  after_update :review_active_state!
  after_create_commit :notify_admins!, if: :public_create

  def billable?
    (support? || current_year_membership&.billable? || future_membership&.billable?) &&
      (!Current.acp.sepa? || sepa?)
  end

  def name=(name)
    super name.strip
  end

  def billing_email=(email)
    super email.strip.presence
  end

  def billing_emails
    if billing_email
      EmailSuppression.outbound.active.exists?(email: billing_email) ? [] : [ billing_email ]
    else
      active_emails
    end
  end

  def billing_emails?
    billing_emails.any?
  end

  def display_address
    return if address.blank?

    parts = []
    parts << address
    parts << "#{zip} #{city}"
    parts << country.translations[I18n.locale.to_s]
    parts.join("<br/>").html_safe
  end

  def country
    ISO3166::Country.new(country_code)
  end

  def sepa?
    iban? && sepa_mandate_id? && sepa_mandate_signed_on?
  end

  def display_delivery_address
    return if final_delivery_address.blank?

    parts = []
    parts << final_delivery_address
    parts << "#{final_delivery_zip} #{final_delivery_city}"
    parts.join("<br/>").html_safe
  end

  def same_delivery_address?
    [ final_delivery_address, final_delivery_city, final_delivery_zip ] == [ address, city, zip ]
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

  def use_shop_depot?
    shop_depot.present? && current_or_future_membership.nil?
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i[with_name with_address with_email with_phone with_waiting_depots_eq]
  end

  def update_trial_baskets!
    return if Current.acp.trial_basket_count.zero?

    transaction do
      baskets.trial.update_all(state: "normal")
      baskets.normal.limit(Current.acp.trial_basket_count).update_all(state: "trial")
    end
  end

  def validate!(validator, skip_email: false)
    invalid_transition(:validate!) unless pending?

    if waiting_basket_size_id? || waiting_depot_id?
      self.waiting_started_at ||= Time.current
      self.state = WAITING_STATE
    elsif annual_fee&.positive? || desired_acp_shares_number.positive?
      self.state = SUPPORT_STATE
    else
      self.state = INACTIVE_STATE
    end
    self.validated_at = Time.current
    self.validator = validator
    save!

    if !skip_email && emails?
      MailTemplate.deliver_later(:member_validated, member: self)
    end
  end

  def wait!
    invalid_transition(:wait!) unless can_wait?

    self.state = WAITING_STATE
    self.waiting_started_at = Time.current
    self.annual_fee ||= Current.acp.annual_fee
    save!
  end

  def review_active_state!
    return if pending?

    if current_or_future_membership || shop_depot
      activate! unless active?
    elsif active?
      if last_membership&.renewal_annual_fee&.positive?
        support!(annual_fee: last_membership.renewal_annual_fee)
      elsif acp_shares_number.positive?
        support!
      else
        deactivate!
      end
    end
  end

  def activate!
    invalid_transition(:activate!) unless current_or_future_membership || shop_depot
    return if active?

    self.state = ACTIVE_STATE
    self.annual_fee ||= Current.acp.annual_fee
    self.activated_at ||= Time.current
    save!

    if activated_at_previously_changed? && emails?
      MailTemplate.deliver_later(:member_activated, member: self)
    end
  end

  def support!(annual_fee: nil)
    invalid_transition(:support!) if support?

    update!(
      state: SUPPORT_STATE,
      annual_fee: annual_fee,
      waiting_started_at: nil)
  end

  def deactivate!
    invalid_transition(:deactivate!) unless can_deactivate?

    update!(
      state: INACTIVE_STATE,
      shop_depot: nil,
      annual_fee: nil,
      desired_acp_shares_number: 0,
      waiting_started_at: nil)
  end

  def can_wait?
    support? || inactive?
  end

  def can_deactivate?
    !inactive? && (
      waiting? ||
      (support? && !Current.acp.share?) ||
      (!support? && !current_or_future_membership))
  end

  def absent?(date)
    absences.any? { |absence| absence.period.include?(date.to_date) }
  end

  def membership(year = nil)
    year ||= Current.fiscal_year
    memberships.during_year(year).first
  end

  def can_destroy?
    pending? || (inactive? &&
      memberships.none? &&
      invoices.none? &&
      payments.none? &&
      shop_orders.none?)
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
    [ balance_amount, 0 ].max
  end

  def acp_shares_number
    existing_acp_shares_number.to_i + invoices.not_canceled.acp_share.sum(:acp_shares_number)
  end

  def required_acp_shares_number=(value)
    self[:required_acp_shares_number] = value.presence
  end

  def required_acp_shares_number
    (self[:required_acp_shares_number] ||
      default_required_acp_shares_number).to_i
  end

  def default_required_acp_shares_number
    current_or_future_membership&.basket_size&.acp_shares_number.to_i
  end

  def missing_acp_shares_number
    [ [ required_acp_shares_number, desired_acp_shares_number ].max - acp_shares_number, 0 ].max
  end

  def handle_acp_shares_change!
    if acp_shares_number.positive?
      update_column(:state, SUPPORT_STATE) if inactive?
    elsif support?
      update_column(:state, INACTIVE_STATE)
    end
  end

  private

  def set_defaults
    self[:country_code] ||= Current.acp.country_code
  end

  def set_default_billing_year_division
    unless self[:billing_year_division].in?(Current.acp.billing_year_divisions)
      self[:billing_year_division] = Current.acp.billing_year_divisions.last
    end
  end

  def set_default_waiting_delivery_cycle
    return unless waiting_basket_size
    return unless waiting_depot

    self.waiting_delivery_cycle ||=
      waiting_basket_size.delivery_cycle || waiting_depot.delivery_cycles.greatest
  end

  def email_must_be_unique
    emails_array.each do |email|
      if Member.where.not(id: id).including_email(email).exists?
        errors.add(:emails, :taken)
        break
      end
    end
  end

  def unique_waiting_basket_complement_id
    used_basket_complement_ids = []
    members_basket_complements.each do |mbc|
      if mbc.basket_complement_id.in?(used_basket_complement_ids)
        mbc.errors.add(:basket_complement_id, :taken)
        errors.add(:base, :invalid)
      end
      used_basket_complement_ids << mbc.basket_complement_id
    end
  end

  def public_create_and_not_support?
    public_create && !support?
  end

  def update_membership_if_salary_basket_changed
    return unless saved_change_to_attribute?(:salary_basket)

    [ current_year_membership, future_membership ].compact.each(&:save!)
  end

  def handle_annual_fee_change
    return unless Current.acp.annual_fee?

    if annual_fee&.positive?
      self.state = SUPPORT_STATE if inactive?
    elsif support?
      self.annual_fee = nil
      self.state = INACTIVE_STATE
    end
  end

  def notify_admins!
    Admin.notify!(:new_inscription, member: self)
  end
end
