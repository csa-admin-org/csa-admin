# frozen_string_literal: true

require "public_suffix"

class Organization < ApplicationRecord
  FEATURES = %i[
    absence
    activity
    basket_content
    basket_price_extra
    bidding_round
    contact_sharing
    local_currency
    new_member_fee
    shop
  ]
  RESTRICTED_FEATURES = %i[]
  FEATURE_FLAGS = %i[]
  LANGUAGES = %w[fr de it nl en]
  MEMBER_FORM_MODES = %w[membership shop]
  INPUT_FORM_MODES = %w[hidden visible required]
  DELIVERY_PDF_MEMBER_INFOS = %w[none phones food_note]
  MEMBERS_SUBDOMAINS = %w[membres mitglieder soci members]

  def self.features
    (FEATURES | Current.org.features)
      .sort_by { |f| I18n.transliterate I18n.t("features.#{f}") }
  end
  def self.feature_flags = FEATURE_FLAGS
  def self.restricted_features = RESTRICTED_FEATURES
  def self.languages = LANGUAGES

  include HasSocialNetworkUrls
  include TranslatedAttributes
  include TranslatedRichTexts
  include NormalizedString
  include Billing, Trial
  include \
    AbsenceFeature,
    ActivityFeature,
    BasketPriceExtraFeature,
    BiddingRoundFeature,
    LocalCurrencyFeature,
    NewMemberFeeFeature,
    ShopFeature

  attribute :icalendar_auth_token, :string, default: -> { SecureRandom.hex(16) }

  translated_attributes :invoice_document_name, :invoice_info, :invoice_footer
  translated_attributes :invoice_sepa_info, :invoice_footer
  translated_attributes :delivery_pdf_footer
  translated_attributes :charter_url, :statutes_url, :terms_of_service_url, :privacy_policy_url
  translated_attributes :email_signature, :email_footer
  translated_rich_texts :open_renewal_text
  translated_rich_texts :membership_update_text
  translated_rich_texts :member_information_text
  translated_attributes :member_information_title
  translated_rich_texts :member_form_subtitle
  translated_rich_texts :member_form_extra_text
  translated_rich_texts :member_form_complements_text

  normalized_string_attributes :creditor_name, :creditor_street, :creditor_city, :creditor_zip

  has_secure_token :api_token, length: 36

  encrypts :postmark_server_token

  has_one_attached :logo
  has_many_attached :invoice_logos

  validates :name, presence: true
  validates :email, presence: true
  validates :email_default_from, presence: true
  validates :email_default_from, format: { with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ }
  validates :email_default_from, format: { with: ->(org) { /.*@#{org.domain}\z/ } }
  validates_plausible_phone :phone, country_code: ->(org) { org.country_code }
  validates_plausible_phone :activity_phone, country_code: ->(org) { org.country_code }

  validates :open_renewal_reminder_sent_after_in_days,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :country_code,
    presence: true,
    inclusion: { in: ISO3166::Country.all.map(&:alpha2) }
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
  validate :only_one_organization, on: :create

  before_create :set_defaults
  after_create :create_default_configurations

  def self.instance
    first!
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

  def phone=(phone)
    super PhonyRails.normalize_number(phone, default_country_code: country_code)
  end

  def phone
    super.presence&.phony_formatted(format: :international)
  end

  def languages=(languages)
    super languages & LANGUAGES
  end

  def languages
    super & LANGUAGES
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

  def domain
    @domain ||= PublicSuffix.parse(Tenant.admin_host).domain
  end

  def members_subdomain
    @members_subdomain ||= PublicSuffix.parse(Tenant.members_host).trd
  end

  def members_url(**params)
    url = "https://#{Tenant.members_host}"
    url += "?#{params.to_query}" if params.any?
    url
  end

  def admin_url(**params)
    url = "https://#{Tenant.admin_host}"
    url += "?#{params.to_query}" if params.any?
    url
  end

  def hostnames
    [
      admin_url,
      members_url
    ].map { |url| URI.parse(url).host }
  end

  private

  def only_one_organization
    return if Organization.count.zero?

    errors.add(:base, "Only one organization is allowed")
  end

  def set_defaults
    self.url = "https://#{domain}"
    self.invoice_infos = default_invoice_infos
    self.invoice_footer = [ phone, email ].map(&:presence).compact.join(" / ")
    self.email_footers = default_email_footers
    self.email_signatures = default_email_signatures
  end

  def default_invoice_infos
    Organization.languages.reduce({}) do |h, locale|
      h[locale] = I18n.with_locale(locale) { I18n.t("organization.default_invoice_info") }
      h
    end
  end

  def default_email_footers
    Organization.languages.reduce({}) do |h, locale|
      h[locale] = I18n.with_locale(locale) {
        txt = I18n.t("organization.default_email_footer")
        txt += "\n#{creditor_name}, #{creditor_street}, #{creditor_zip} #{creditor_city}"
      }
      h
    end
  end

  def default_email_signatures
    Organization.languages.reduce({}) do |h, locale|
      h[locale] = I18n.with_locale(locale) {
        txt = I18n.t("organization.default_email_signature")
        txt += "\n#{name}"
      }
      h
    end
  end

  def create_default_configurations
    Permission.create_superadmin!
    Admin.create_ultra!
    DeliveryCycle.create_default!
    MailTemplate.create_all!
    Newsletter::Template.create_defaults!
  end
end

# Alias
Org = Organization unless defined?(Org)
