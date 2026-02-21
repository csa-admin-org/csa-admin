# frozen_string_literal: true

require "sepa_king"

class Member < ApplicationRecord
  include HasState
  include HasName
  include HasEmails
  include HasPhones
  include HasLanguage
  include HasSessions
  include HasTheme
  include HasIBAN
  include Auditable
  include NormalizedString
  include Searchable
  # Sub-model concerns (order matters for callbacks!)
  include Billing
  include Shares
  include StateTransitions
  include Discardable
  include Anonymization

  searchable :name, :emails, :city, :zip, :id, priority: 1

  BILLING_INTERVALS = %w[annual quarterly].freeze
  generates_token_for :calendar

  # Temporary attributes for Delivery XLSX worksheet
  attr_accessor :basket, :shop_order

  attr_accessor :public_create
  attribute :language, :string, default: -> { Current.org.languages.first }
  attribute :country_code, :string, default: -> { Current.org.country_code }
  attribute :trial_baskets_count, :integer, default: -> { Current.org.trial_baskets_count }
  attribute :different_billing_info, :boolean, default: -> { false }
  attribute :send_validation_email, :boolean, default: -> { false }

  audited_attributes \
    :state, :name, :emails, :billing_email, :phones, :contact_sharing, \
    :street, :zip, :city, :country_code, \
    :billing_name, :billing_street, :billing_city, :billing_zip, \
    :profession, :come_from, :note, :delivery_note, :food_note, \
    :annual_fee, :shares_info, :existing_shares_number, :required_shares_number, :desired_shares_number, \
    :shop_depot_id, :salary_basket, \
    :iban, :sepa_mandate_id, :sepa_mandate_signed_on
  normalized_string_attributes :name, :street, :city, :zip
  normalized_string_attributes :billing_name, :billing_street, :billing_city, :billing_zip
  normalizes :sepa_mandate_id, :iban, with: ->(value) { value.to_s.strip.presence }

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
  has_many :mail_deliveries, dependent: :destroy

  accepts_nested_attributes_for :members_basket_complements, allow_destroy: true

  scope :sepa, -> { where.not(sepa_mandate_id: [ nil, "" ]) }
  scope :not_sepa, -> { where(sepa_mandate_id: nil) }
  scope :sepa_eq, ->(bool) { ActiveRecord::Type::Boolean.new.cast(bool) ? sepa : not_sepa }
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
  validates :street, :city, :zip, :country_code, presence: true, unless: :inactive?
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

  validates :trial_baskets_count, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :iban, presence: true, if: :sepa_mandate_id?
  validates :iban, format: -> { ::Billing.iban_format }, allow_nil: :true
  validates_with SEPA::IBANValidator, if: :sepa_mandate_id?
  validates :sepa_mandate_id, uniqueness: true, presence: true, if: :sepa_mandate_signed_on?
  validates_with SEPA::MandateIdentifierValidator, field_name: :sepa_mandate_id, if: :sepa_mandate_id?
  validates :sepa_mandate_signed_on, presence: true, if: :sepa_mandate_id?

  after_initialize :set_default_annual_fee
  before_save :handle_annual_fee_change
  after_save :update_membership_if_salary_basket_changed
  after_update :update_trial_baskets!, if: :trial_baskets_count_previously_changed?
  after_commit :enqueue_dependent_search_reindex,
    if: -> { saved_change_to_name? || saved_change_to_emails? || saved_change_to_city? || saved_change_to_zip? }

  def name=(name)
    super name&.strip
  end

  def country
    ISO3166::Country.new(country_code)
  end

  def time_zone
    Current.org.time_zone unless country_code?

    country.timezones.zone_info.first.identifier
  end

  def shop_depot
    use_shop_depot? ? super : current_or_future_membership&.depot
  end

  def use_shop_depot?
    shop_depot_id? && current_or_future_membership.nil?
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[ sepa_eq with_email with_phone with_waiting_depots_eq]
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
      recent_baskets.normal.where("baskets.quantity > 0").limit(trial_baskets_count).update_all(state: "trial")
      recent_baskets.map(&:membership).uniq.each(&:update_baskets_counts!)
    end
  end

  def absent?(date)
    absences.any? { |absence| absence.date_range.include?(date.to_date) }
  end

  def closest_membership
    current_or_future_membership || last_membership
  end

  def membership(year = nil)
    year ||= Current.fiscal_year
    memberships.during_year(year).first
  end

  private

  def enqueue_dependent_search_reindex
    SearchReindexDependentsJob.perform_later(self)
  end

  def set_default_annual_fee
    return unless new_record?
    return if annual_fee
    return unless Current.org.annual_fee&.positive?

    unless Current.org.annual_fee_support_member_only? && waiting_basket_size_id?
      self[:annual_fee] ||= Current.org.annual_fee
    end
  end

  def set_default_waiting_billing_year_division
    if (waiting_basket_size_id? && !waiting_billing_year_division?)
        || (waiting_billing_year_division? && !waiting_billing_year_division.in?(Current.org.billing_year_divisions))
      self[:waiting_billing_year_division] = Current.org.billing_year_divisions.last
    end
  end

  def set_default_waiting_delivery_cycle
    return unless waiting_basket_size
    return unless waiting_depot

    self.waiting_delivery_cycle ||= waiting_depot.delivery_cycles.primary
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
    return unless Current.org.annual_fee?

    if !annual_fee.nil?
      self.state = SUPPORT_STATE if inactive?
    elsif support?
      self.state = INACTIVE_STATE
    end
  end
end
