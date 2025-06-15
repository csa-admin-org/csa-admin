# frozen_string_literal: true

class Organization < ApplicationRecord
  include HasSocialNetworkUrls
  include TranslatedAttributes
  include TranslatedRichTexts
  include NormalizedString
  include HasIBAN

  FEATURES = %i[
    absence
    activity
    basket_content
    basket_price_extra
    contact_sharing
    new_member_fee
    shop
  ]
  FEATURE_FLAGS = %i[]
  LANGUAGES = %w[fr de it en]
  CURRENCIES = %w[CHF EUR]
  BILLING_YEAR_DIVISIONS = [ 1, 2, 3, 4, 12 ]
  ACTIVITY_I18N_SCOPES = %w[hour_work halfday_work day_work basket_preparation]
  MEMBER_FORM_MODES = %w[membership shop]
  INPUT_FORM_MODES = %w[hidden visible required]
  DELIVERY_PDF_MEMBER_INFOS = %w[none phones food_note]
  MEMBERS_SUBDOMAINS = %w[membres mitglieder soci members]
  ACTIVITY_PARTICIPATIONS_DEMANDED_LOGIC_DEFAULT = <<-LIQUID
    {% if member.salary_basket %}
      0
    {% else %}
      {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_activity_participations | round }}
    {% endif %}
  LIQUID

  attribute :shop_delivery_open_last_day_end_time, :time_only
  attribute :icalendar_auth_token, :string, default: -> { SecureRandom.hex(16) }
  attribute :activity_participations_demanded_logic, :string, default: -> {
    ACTIVITY_PARTICIPATIONS_DEMANDED_LOGIC_DEFAULT
  }

  translated_attributes :invoice_document_name, :invoice_info, :invoice_footer
  translated_attributes :invoice_sepa_info, :invoice_footer
  translated_attributes :delivery_pdf_footer
  translated_attributes :charter_url, :statutes_url, :terms_of_service_url, :privacy_policy_url
  translated_attributes :shop_invoice_info
  translated_attributes :shop_delivery_pdf_footer
  translated_attributes :shop_terms_of_sale_url
  translated_rich_texts :shop_text
  translated_attributes :email_signature, :email_footer
  translated_rich_texts :open_renewal_text
  translated_attributes :basket_price_extra_title, :basket_price_extra_public_title, :basket_price_extra_text
  translated_attributes :basket_price_extra_label, :basket_price_extra_label_detail
  translated_rich_texts :absence_extra_text
  translated_rich_texts :membership_update_text
  translated_rich_texts :member_information_text
  translated_attributes :member_information_title
  translated_rich_texts :member_form_subtitle
  translated_rich_texts :member_form_extra_text
  translated_rich_texts :member_form_complements_text
  translated_attributes :activity_participations_form_detail
  translated_attributes :new_member_fee_description

  normalized_string_attributes :creditor_name, :creditor_address, :creditor_city, :creditor_zip

  has_one_attached :logo
  has_one_attached :invoice_logo

  validates :name, presence: true
  validates :url,
    presence: true,
    format: { with: ->(org) { %r{\Ahttps?://.*#{Tenant.domain}\z} } }
  validates :email, presence: true
  validates :members_subdomain, inclusion: { in: MEMBERS_SUBDOMAINS }
  validates :email_default_from, presence: true
  validates :email_default_from, format: { with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ }
  validates :email_default_from, format: { with: ->(org) { /.*@#{Tenant.domain}\z/ } }
  validates_plausible_phone :phone, country_code: ->(org) { org.country_code }
  validates_plausible_phone :activity_phone, country_code: ->(org) { org.country_code }
  validates :creditor_name, :creditor_address, :creditor_city, :creditor_zip, presence: true
  validates :bank_reference, format: { with: /\A\d+\z/, allow_blank: true }
  validates :iban, format: ->(org) { Billing.iban_format(org.country_code) }, allow_nil: true, if: :country_code?
  validates :fiscal_year_start_month,
    presence: true,
    inclusion: { in: 1..12 }
  validates_with SEPA::CreditorIdentifierValidator, field_name: :sepa_creditor_identifier, if: :sepa_creditor_identifier?
  validates :billing_year_divisions, presence: true
  validates :trial_baskets_count, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :annual_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :annual_fee_member_form, absence: true, unless: :annual_fee?
  validates :share_price, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :share_price, presence: true, if: :shares_number?
  validates :shares_number, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :shares_number, presence: true, if: :share_price?
  validates :absence_notice_period_in_days,
    numericality: { greater_than_or_equal_to: 1 }
  validates :activity_i18n_scope, inclusion: { in: ACTIVITY_I18N_SCOPES }
  validates :activity_participation_deletion_deadline_in_days,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :activity_availability_limit_in_days,
    numericality: { greater_than_or_equal_to: 0 }
  validates :activity_price,
    numericality: { greater_than_or_equal_to: 0 }
  validates :activity_participations_form_min, :activity_participations_form_max,
    numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :activity_participations_form_step,
    numericality: { greater_than_or_equal_to: 1 }, presence: true
  validate :activity_participations_demanded_logic_must_be_valid
  validate :basket_price_extra_dynamic_pricing_logic_must_be_valid
  validates :open_renewal_reminder_sent_after_in_days,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :vat_number, presence: true, if: -> {
    vat_membership_rate&.positive? || vat_activity_rate&.positive? || vat_shop_rate&.positive?
  }
  validates :vat_membership_rate, numericality: { greater_or_equal_to_than: 0, allow_nil: true }
  validates :vat_activity_rate, numericality: { greater_or_equal_to_than: 0, allow_nil: true }
  validates :vat_shop_rate, numericality: { greater_or_equal_to_than: 0, allow_nil: true }
  validates :recurring_billing_wday, inclusion: { in: 0..6 }, allow_nil: true
  validates :country_code,
    presence: true,
    inclusion: { in: ISO3166::Country.all.map(&:alpha2) }
  validates :currency_code, presence: true, inclusion: { in: CURRENCIES }
  validates :shop_order_maximum_weight_in_kg,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :shop_order_minimal_amount,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :shop_order_automatic_invoicing_delay_in_days,
    numericality: { only_integer: true, allow_nil: true }
  validates :member_form_mode, presence: true, inclusion: { in: MEMBER_FORM_MODES }
  validates :member_profession_form_mode, presence: true, inclusion: { in: INPUT_FORM_MODES }
  validates :member_come_from_form_mode, presence: true, inclusion: { in: INPUT_FORM_MODES }
  validates :basket_sizes_member_order_mode,
    presence: true,
    inclusion: { in: BasketSize::MEMBER_ORDER_MODES }
  validates :basket_complements_member_order_mode,
    presence: true,
    inclusion: { in: BasketComplement::MEMBER_ORDER_MODES }
  validates :depots_member_order_mode,
    presence: true,
    inclusion: { in: Depot::MEMBER_ORDER_MODES }
  validates :delivery_cycles_member_order_mode,
    presence: true,
    inclusion: { in: DeliveryCycle::MEMBER_ORDER_MODES }
  validates :delivery_pdf_member_info,
    presence: true,
    inclusion: { in: DELIVERY_PDF_MEMBER_INFOS }
  validates :basket_update_limit_in_days,
    presence: true,
    numericality: { greater_than_or_equal_to: 0 }
  validates :basket_shifts_annually,
    numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :basket_shift_deadline_in_weeks,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :new_member_fee,
    presence: true,
    numericality: { greater_than_or_equal_to: 0 },
    if: -> { feature?("new_member_fee") && new_member_fee_description? }
  validates :new_member_fee_description,
    presence: true,
    if: -> { feature?("new_member_fee") && new_member_fee? }
  validate :only_one_organization, on: :create

  after_save :apply_annual_fee_change
  after_create :create_default_configurations

  def self.features
    (FEATURES | Current.org.features)
      .sort_by { |f| I18n.transliterate I18n.t("features.#{f}") }
  end
  def self.languages; LANGUAGES end
  def self.feature_flags; FEATURE_FLAGS end
  def self.activity_i18n_scopes; ACTIVITY_I18N_SCOPES end
  def self.billing_year_divisions; BILLING_YEAR_DIVISIONS end

  def self.instance
    first!
  end

  def number
    Tenant.numbered.find { |i, tenant|
      tenant == Tenant.current
    }.first
  end

  def features
    self[:features].map(&:to_sym) & FEATURES
  end

  def feature_flags
    self[:feature_flags].map(&:to_sym) & FEATURE_FLAGS
  end

  def feature?(feature)
    features.include?(feature.to_sym)
  end

  def feature_flag?(feature)
    feature_flags.include?(feature.to_sym)
  end

  def terms_of_service?
    charter_url || statutes_url || terms_of_service_url || privacy_policy_url
  end

  def trial_baskets?
    trial_baskets_count.positive?
  end

  def recurring_billing?
    !!recurring_billing_wday
  end

  def send_invoice_overdue_notice?
    automatic_payments_processing? && MailTemplate.active_template("invoice_overdue_notice")
  end

  def automatic_payments_processing?
    [ credentials(:ebics), credentials(:bas) ].any?(&:present?)
  end

  def billing_year_divisions=(divisions)
    super divisions.map(&:presence).compact.map(&:to_i) & BILLING_YEAR_DIVISIONS
  end

  def phone=(phone)
    super PhonyRails.normalize_number(phone, default_country_code: country_code)
  end

  def phone
    super.presence&.phony_formatted(format: :international)
  end

  def activity_phone=(phone)
    super PhonyRails.normalize_number(phone, default_country_code: country_code)
  end

  def activity_phone
    super.presence&.phony_formatted(format: :international)
  end

  def languages=(languages)
    super languages & self.class.languages
  end

  def languages
    super & self.class.languages
  end

  def default_locale
    if languages.include?(I18n.default_locale.to_s)
      I18n.default_locale.to_s
    else
      languages.first
    end
  end

  def country
    ISO3166::Country.new(country_code)
  end

  def time_zone
    country.timezones.zone_info.first.identifier
  end

  def sepa?
    country_code == "DE"
  end

  def email_default_from_address
    Mail::Address.new.tap { |builder|
      builder.address = email_default_from
      builder.display_name = name
    }.to_s
  end

  def members_url
    "https://#{members_subdomain}.#{Tenant.domain}"
  end

  def admin_url
    "https://admin.#{Tenant.domain}"
  end

  def hostnames
    [
      admin_url,
      members_url
    ].map { |url| URI.parse(url).host }
  end

  def activity_participations_form?
    activity_participations_form_min || activity_participations_form_max
  end

  def basket_price_extra_title
    self[:basket_price_extra_titles][I18n.locale.to_s].presence ||
      self.class.human_attribute_name(:basket_price_extra)
  end

  def basket_price_extra_public_title
    self[:basket_price_extra_public_titles][I18n.locale.to_s].presence ||
      basket_price_extra_title
  end

  def basket_price_extra_label_detail_default
    "{% if extra != 0 %}{{ full_year_price }}{% endif %}"
  end

  def basket_price_extra_label_detail_or_default
    basket_price_extra_label_detail.presence || basket_price_extra_label_detail_default
  end

  def basket_price_extras?
    self[:basket_price_extras].any?
  end

  def basket_price_extras
    self[:basket_price_extras].join(", ")
  end

  def basket_price_extras=(string)
    self[:basket_price_extras] = string.split(",").map(&:presence).compact.map(&:to_f)
  end

  def shop_member_percentages?
    self[:shop_member_percentages].any?
  end

  def shop_member_percentages
    self[:shop_member_percentages].join(", ")
  end

  def shop_member_percentages=(string)
    self[:shop_member_percentages] =
      string
        .split(",")
        .map(&:presence)
        .compact
        .map(&:to_i)
        .reject(&:zero?)
        .sort
  end

  def fiscal_years
    min_year = Delivery.minimum(:date)&.year || Date.today.year
    max_year = Delivery.maximum(:date)&.year || Date.today.year
    (min_year..max_year).map { |year|
      Current.org.fiscal_year_for(year)
    }
  end

  def current_fiscal_year
    FiscalYear.current(start_month: fiscal_year_start_month)
  end

  def last_fiscal_year
    fiscal_year_for(current_fiscal_year.year - 1)
  end

  def next_fiscal_year
    fiscal_year_for(current_fiscal_year.year + 1)
  end

  def fiscal_year_for(date_or_year)
    return unless date_or_year

    FiscalYear.for(date_or_year, start_month: fiscal_year_start_month)
  end

  def fy_month_for(date)
    fiscal_year_for(date).month(date)
  end

  def member_support?
    annual_fee? || share?
  end

  def annual_fee?
    annual_fee && annual_fee >= 0
  end

  def share?
    share_price&.positive?
  end

  def credentials(*keys)
    Rails.application.credentials.dig(:organizations, Tenant.current.to_sym, *keys)
  end

  def deliveries_count(year)
    @max_deliveries_counts ||=
      DeliveryCycle
        .pluck(:deliveries_counts)
        .reduce({}) { |h, i| h.merge(i) { |k, old, new| [ old, new ].flatten.max } }
    @max_deliveries_counts[year.to_s]
  end

  def calculate_basket_price_extra(extra, basket_price, basket_size_id, complements_price, deliveries_count)
    return extra unless basket_price_extra_dynamic_pricing?

    template = Liquid::Template.parse(basket_price_extra_dynamic_pricing)
    template.render(
      "extra" => extra.to_f,
      "basket_price" => basket_price.to_f,
      "basket_size_id" => basket_size_id,
      "complements_price" => complements_price.to_f,
      "deliveries_count" => deliveries_count.to_f
    ).to_f
  end

  def basket_shift_enabled?
    absences_billed? && basket_shifts_annually != 0
  end

  def basket_shift_annual_limit?
    basket_shifts_annually.positive?
  end

  def basket_shift_deadline_enabled?
    basket_shift_deadline_in_weeks.present?
  end

  def basket_shift_allowed_range_for(basket)
    return unless basket_shift_deadline_enabled?

    absence = basket.absence
    deadline = basket_shift_deadline_in_weeks.weeks
    ([ absence.started_on - deadline, Date.tomorrow ].max)..(absence.ended_on + deadline)
  end

  private

  def only_one_organization
    return if Organization.count.zero?

    errors.add(:base, "Only one organization is allowed")
  end

  def create_default_configurations
    Permission.create_superadmin!
    DeliveryCycle.create_default!
    MailTemplate.create_all!
    Newsletter::Template.create_defaults!
  end

  def activity_participations_demanded_logic_must_be_valid
    Liquid::Template.parse(activity_participations_demanded_logic)
  rescue Liquid::SyntaxError => e
    errors.add(:activity_participations_demanded_logic, e.message)
  end

  def basket_price_extra_dynamic_pricing_logic_must_be_valid
    Liquid::Template.parse(basket_price_extra_dynamic_pricing)
  rescue Liquid::SyntaxError => e
    errors.add(:basket_price_extra_dynamic_pricing, e.message)
  end

  def apply_annual_fee_change
    return unless annual_fee_previously_changed?

    Member
      .where(annual_fee: annual_fee_previously_was)
      .update_all(annual_fee: annual_fee)
  end
end

# Alias
Org = Organization
