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
  include Auditing
  include NormalizedString
  include Searchable
  # Sub-model concerns (order matters for callbacks!)
  include Billing
  include SEPA
  include Shares
  include Shop
  include Waiting
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

  normalized_string_attributes :name, :street, :city, :zip
  normalized_string_attributes :billing_name, :billing_street, :billing_city, :billing_zip

  has_states :pending, :waiting, :active, :support, :inactive

  belongs_to :validator, class_name: "Admin", optional: true
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
  has_many :mail_deliveries, dependent: :destroy

  scope :not_pending, -> { where.not(state: "pending") }
  scope :not_inactive, -> { where.not(state: "inactive") }
  scope :trial, -> { joins(:current_membership).merge(Membership.trial) }
  scope :sharing_contact, -> { where(contact_sharing: true) }
  scope :no_salary_basket, -> { where(salary_basket: false) }

  validates_acceptance_of :terms_of_service
  validates :country_code,
    inclusion: { in: ISO3166::Country.all.map(&:alpha2), allow_blank: true }
  validates :emails, presence: true, if: :public_create
  validates :phones, presence: true, if: :public_create
  validates :profession, presence: true,
    if: -> { public_create && Current.org.member_profession_form_mode == "required" }
  validates :come_from, presence: true,
    if: -> { public_create && Current.org.member_come_from_form_mode == "required" }
  validates :street, :city, :zip, :country_code, presence: true, unless: :inactive?
  validates :annual_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :annual_fee,
    presence: true,
    numericality: { greater_than_or_equal_to: 1 },
    on: :create,
    if: -> { public_create && Current.org.feature?("annual_fee") && Current.org.annual_fee_member_form? && !waiting_basket_size_id? }
  validate :email_must_be_unique

  validates :trial_baskets_count, numericality: { greater_than_or_equal_to: 0 }, presence: true

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

  def trial?
    memberships.current_or_future.where(remaining_trial_baskets_count: 1..).exists?
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
    return unless Current.org.feature?("annual_fee")
    return unless Current.org.annual_fee&.positive?

    unless Current.org.annual_fee_support_member_only? && waiting_basket_size_id?
      self[:annual_fee] ||= Current.org.annual_fee
    end
  end

  def email_must_be_unique
    emails_array.each do |email|
      if Member.kept.where.not(id: id).including_email(email).exists?
        errors.add(:emails, :taken)
        break
      end
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
    return unless Current.org.feature?("annual_fee")

    if !annual_fee.nil?
      self.state = SUPPORT_STATE if inactive?
    elsif support?
      self.state = INACTIVE_STATE
    end
  end
end
