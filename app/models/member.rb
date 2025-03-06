# frozen_string_literal: true

class Member < ApplicationRecord
  include HasState
  include HasName
  include HasEmails
  include HasPhones
  include HasLanguage
  include HasSessions
  include HasIBAN
  include Auditable
  include NormalizedString

  BILLING_INTERVALS = %w[annual quarterly].freeze

  generates_token_for :calendar

  # Temporary attributes for Delivery XLSX worksheet
  attr_accessor :basket, :shop_order

  attr_accessor :public_create
  attribute :language, :string, default: -> { Current.org.languages.first }
  attribute :country_code, :string, default: -> { Current.org.country_code }
  attribute :trial_baskets_count, :integer, default: -> { Current.org.trial_baskets_count }

  audited_attributes \
    :state, :name, :emails, :billing_email, :newsletter, :phones, :contact_sharing, \
    :address, :zip, :city, :country_code, \
    :delivery_address, :delivery_zip, :delivery_city, :delivery_country_code, \
    :profession, :come_from, :note, :delivery_note, :food_note, \
    :annual_fee, :shares_info, :existing_shares_number, :required_shares_number, :desired_shares_number, \
    :shop_depot_id, \
    :iban, :sepa_mandate_id, :sepa_mandate_signed_on
  normalized_string_attributes :name, :address, :city, :zip

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
  scope :no_salary_basket, -> { where(salary_basket: false) }
  scope :with_waiting_depots_eq, ->(depot_id) {
    left_joins(:members_waiting_alternative_depots).where(<<-SQL, depot_id: depot_id).distinct
      members.waiting_depot_id = :depot_id OR
      members_waiting_alternative_depots.depot_id = :depot_id
    SQL
  }

  before_validation :set_default_waiting_billing_year_division
  before_validation :set_default_waiting_delivery_cycle

  validates_acceptance_of :terms_of_service
  validates :waiting_billing_year_division,
    inclusion: { in: proc { Current.org.billing_year_divisions }, allow_nil: true },
    on: :create,
    if: :public_create
  validates :waiting_billing_year_division,
    inclusion: { in: Organization.billing_year_divisions, allow_nil: true }
  validates :country_code,
    inclusion: { in: ISO3166::Country.all.map(&:alpha2), allow_blank: true }
  validates :emails, presence: true, if: :public_create
  validates :phones, presence: true, if: :public_create
  validates :profession, presence: true,
    if: -> { public_create && Current.org.member_profession_form_mode == "required" }
  validates :come_from, presence: true,
    if: -> { public_create && Current.org.member_come_from_form_mode == "required" }
  validates :address, :city, :zip, :country_code, presence: true, unless: :inactive?
  validates :waiting_basket_size, inclusion: { in: proc { BasketSize.all }, allow_nil: true }, on: :create
  validates :waiting_basket_size_id, presence: true, if: :waiting_depot, on: :create
  validates :waiting_activity_participations_demanded_annually, numericality: true, allow_nil: true
  validates :waiting_activity_participations_demanded_annually,
    numericality: {
      greater_than_or_equal_to: -> { Current.org.activity_participations_form_min || 0 },
      less_than_or_equal_to: -> { Current.org.activity_participations_form_max || 1000 },
      allow_nil: true
    },
    if: -> { public_create && Current.org.feature?("activity") }
  validates :waiting_basket_price_extra, presence: true, if: -> { public_create && Current.org.feature?("basket_price_extra") && waiting_depot }, on: :create
  validates :waiting_depot, inclusion: { in: proc { Depot.all }, allow_nil: true }, on: :create
  validates :waiting_depot_id, presence: true, if: :waiting_basket_size, on: :create
  validates :shop_depot, inclusion: { in: proc { Depot.all }, allow_nil: true }
  validates :annual_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :annual_fee,
    presence: true,
    numericality: { greater_than_or_equal_to: 1 },
    on: :create,
    if: -> { public_create && Current.org.annual_fee? && Current.org.annual_fee_member_form? && !waiting_basket_size_id? }
  validate :email_must_be_unique
  validate :unique_waiting_basket_complement_id
  validates :existing_shares_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :required_shares_number, numericality: { allow_nil: true }
  validates :desired_shares_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :desired_shares_number,
    numericality: {
      greater_than_or_equal_to: ->(m) { m.waiting_basket_size&.shares_number || Current.org.shares_number || 0 }
    },
    if: -> { public_create && Current.org.share? }
  validates :trial_baskets_count, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validate :billing_truemail
  validates :iban, presence: true, if: :sepa_mandate_id?
  validates :iban, format: -> { Billing.iban_format }, allow_nil: :true
  validates :sepa_mandate_id, presence: true, if: :sepa_mandate_signed_on?
  validates_with SEPA::MandateIdentifierValidator, field_name: :sepa_mandate_id, if: :sepa_mandate_id?
  validates :sepa_mandate_signed_on, presence: true, if: :sepa_mandate_id?

  after_initialize :set_default_annual_fee
  before_save :handle_annual_fee_change, :handle_required_shares_number_change
  after_save :update_membership_if_salary_basket_changed
  after_update :review_active_state!
  after_update :update_trial_baskets!, if: :trial_baskets_count_previously_changed?

  def billable?
    support? ||
      missing_shares_number.positive? ||
      current_year_membership&.billable? ||
      future_membership&.billable?
  end

  def name=(name)
    super name&.strip
  end

  def billing_email=(email)
    super email&.strip.presence
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

  def time_zone
    Current.org.time_zone unless country_code?

    country.timezones.zone_info.first.identifier
  end

  def sepa?
    iban? && sepa_mandate_id? && sepa_mandate_signed_on?
  end

  def sepa_metadata
    return {} unless sepa?

    {
      name: name,
      iban: iban,
      mandate_id: sepa_mandate_id,
      mandate_signed_on: sepa_mandate_signed_on
    }
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

  def shop_depot
    use_shop_depot? ? super : current_or_future_membership&.depot
  end

  def use_shop_depot?
    shop_depot_id? && current_or_future_membership.nil?
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[ with_email with_phone with_waiting_depots_eq]
  end

  def update_trial_baskets!
    return unless Current.org.trial_baskets? || trial_baskets_count_previously_changed?

    # Only consider past continuous memberships
    min_date = Current.fiscal_year.beginning_of_year
    while membership = memberships.including_date(min_date - 1.day).first
      min_date = membership.started_on
    end

    recent_baskets = self.baskets.where(deliveries: { date: min_date.. }).includes(:membership)
    transaction do
      recent_baskets.trial.update_all(state: "normal")
      recent_baskets.normal.limit(trial_baskets_count).update_all(state: "trial")
      recent_baskets.map(&:membership).uniq.each(&:update_baskets_counts!)
    end
  end

  def validate!(validator, skip_email: false)
    invalid_transition(:validate!) unless pending?

    if waiting_basket_size_id? || waiting_depot_id?
      self.waiting_started_at ||= Time.current
      self.state = WAITING_STATE
    elsif annual_fee&.positive? || desired_shares_number.positive?
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
    if Current.org.annual_fee_support_member_only?
      self.annual_fee = nil
    else
      self.annual_fee ||= Current.org.annual_fee
    end
    save!
  end

  def review_active_state!
    return if pending?

    if current_or_future_membership || shop_depot
      activate! unless active?
    elsif active?
      if last_membership&.renewal_annual_fee&.positive?
        support!(annual_fee: last_membership.renewal_annual_fee)
      elsif shares_number.positive?
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
    unless Current.org.annual_fee_support_member_only?
      self.annual_fee ||= Current.org.annual_fee
    end
    self.activated_at = Time.current
    save!

    if emails? && (activated_at_previously_was.nil? || activated_at_previously_was < 1.week.ago)
      MailTemplate.deliver_later(:member_activated, member: self)
    end
  end

  def support!(annual_fee: nil)
    invalid_transition(:support!) if support?

    update!(
      state: SUPPORT_STATE,
      annual_fee: annual_fee || Current.org.annual_fee,
      waiting_basket_size_id: nil,
      waiting_started_at: nil)
  end

  def deactivate!
    invalid_transition(:deactivate!) unless can_deactivate?

    attrs = {
      state: INACTIVE_STATE,
      shop_depot: nil,
      annual_fee: nil,
      desired_shares_number: 0,
      waiting_started_at: nil
    }
    if shares_number.positive?
      attrs[:required_shares_number] = -1 * shares_number
    end

    update!(**attrs)
  end

  def can_wait?
    support? || inactive?
  end

  def can_deactivate?
    !inactive? && (
      waiting? ||
      support? ||
      (!support? && !current_or_future_membership)
    )
  end

  def absent?(date)
    absences.any? { |absence| absence.period.include?(date.to_date) }
  end

  def closest_membership
    current_or_future_membership || last_membership
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

  def shares_number
    existing_shares_number.to_i + invoices.not_canceled.share.sum(:shares_number)
  end

  def required_shares_number=(value)
    self[:required_shares_number] = value.presence
  end

  def required_shares_number
    (self[:required_shares_number] ||
      default_required_shares_number).to_i
  end

  def default_required_shares_number
    current_or_future_membership&.basket_size&.shares_number.to_i
  end

  def missing_shares_number
    [ [ required_shares_number, desired_shares_number ].max - shares_number, 0 ].max
  end

  def handle_shares_change!
    if shares_number.positive?
      update_column(:state, SUPPORT_STATE) if inactive?
    elsif support?
      update_column(:state, INACTIVE_STATE)
    end
  end

  private

  def set_default_annual_fee
    return unless new_record?
    return if annual_fee
    return unless Current.org.annual_fee?

    unless Current.org.annual_fee_support_member_only? && waiting_basket_size_id?
      self[:annual_fee] ||= Current.org.annual_fee
    end
  end

  def set_default_waiting_billing_year_division
    if (waiting_basket_size_id? && !waiting_billing_year_division?) ||
        (waiting_billing_year_division? && !waiting_billing_year_division.in?(Current.org.billing_year_divisions))
      self[:waiting_billing_year_division] = Current.org.billing_year_divisions.last
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

  def billing_truemail
    if billing_email && billing_email_changed? && !Truemail.valid?(billing_email)
      errors.add(:billing_email, :invalid)
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
    return unless Current.org.annual_fee?

    if annual_fee&.positive?
      self.state = SUPPORT_STATE if inactive?
    elsif support?
      self.annual_fee = nil
      self.state = INACTIVE_STATE
    end
  end

  def handle_required_shares_number_change
    return unless Current.org.share?

    final_shares_number = [ shares_number, desired_shares_number ].max
    if (final_shares_number + required_shares_number).positive?
      self.state = SUPPORT_STATE if inactive?
    elsif support?
      self.desired_shares_number = 0
      self.state = INACTIVE_STATE
    end
  end
end
