class ACP < ActiveRecord::Base
  include TranslatedAttributes
  include TranslatedRichTexts

  FEATURES = %w[
    absence
    activity
    basket_content
    group_buying
  ]
  FEATURE_FLAGS = %w[basket_price_extra]
  LANGUAGES = %w[fr de]
  SEASONS = %w[summer winter]
  CURRENCIES = %w[CHF EUR]
  BILLING_YEAR_DIVISIONS = [1, 2, 3, 4, 12]
  ACTIVITY_I18N_SCOPES = %w[hour_work halfday_work basket_preparation]

  attr_writer :summer_month_range_min, :summer_month_range_max

  translated_attributes :invoice_info, :invoice_footer
  translated_attributes :delivery_pdf_footer
  translated_attributes :terms_of_service_url, :statutes_url
  translated_attributes :membership_extra_text
  translated_attributes :group_buying_terms_of_service_url
  translated_attributes :group_buying_invoice_info
  translated_attributes :email_signature, :email_footer
  translated_rich_texts :open_renewal_text

  validates :name, presence: true
  validates :host, presence: true
  validates :url, presence: true, format: { with: %r{\Ahttps?://.*\z} }
  validates :logo_url, presence: true, format: { with: %r{\Ahttps://.*\z} }
  validates :email, presence: true
  validates :email_default_host, presence: true, format: { with: %r{\Ahttps://.*\z} }
  validates :email_default_from, presence: true, format: { with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ }
  validates :activity_phone, presence: true, if: -> { feature?('activity') }
  validates :ccp, format: { with: /\A\d{2}-\d{1,6}-\d{1}\z/, allow_blank: true }
  validates :ccp, :isr_identity, :isr_payment_for, :isr_in_favor_of,
    presence: true, if: :isr_invoice?
  validates :ccp, :isr_identity, :isr_payment_for, :isr_in_favor_of,
    absence: true, unless: :isr_invoice?
  validates :qr_iban, :qr_creditor_name, :qr_creditor_address,
    :qr_creditor_city, :qr_creditor_zip,
    presence: true, if: :qr_invoice?
  validates :qr_iban, :qr_creditor_name, :qr_creditor_address,
    :qr_creditor_city, :qr_creditor_zip,
    absence: true, unless: :qr_invoice?
  validates :tenant_name, presence: true
  validates :fiscal_year_start_month,
    presence: true,
    inclusion: { in: 1..12 }
  validates :trial_basket_count, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :annual_fee, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :share_price, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :summer_month_range_min,
    inclusion: { in: 1..12 },
    if: -> { @summer_month_range_max.present? }
  validates :summer_month_range_max,
    inclusion: { in: 1..12 },
    numericality: { greater_than_or_equal_to: ->(acp) { acp.summer_month_range_min } },
    if: -> { @summer_month_range_min.present? }
  validates :activity_i18n_scope, inclusion: { in: ACTIVITY_I18N_SCOPES }
  validates :activity_participation_deletion_deadline_in_days,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :activity_availability_limit_in_days,
    numericality: { greater_than_or_equal_to: 0 }
  validates :activity_price,
    numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :open_renewal_reminder_sent_after_in_days,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :vat_number, presence: true, if: -> { vat_membership_rate&.positive? }
  validates :vat_membership_rate, numericality: { greater_than: 0 }, if: :vat_number?
  validates :recurring_billing_wday, inclusion: { in: 0..6 }, allow_nil: true
  validates :country_code,
    presence: true,
    inclusion: { in: ISO3166::Country.all.map(&:alpha2) }
  validates :currency_code, presence: true, inclusion: { in: CURRENCIES }

  before_save :set_summer_month_range
  after_create :create_tenant

  def self.enter_each!
    ACP.pluck(:tenant_name).each do |tenant_name|
      enter!(tenant_name)
      yield
    end
  ensure
    Apartment::Tenant.reset
    Current.reset
  end

  def self.enter!(tenant_name)
    acp = ACP.find_by!(tenant_name: tenant_name)
    Apartment::Tenant.switch!(acp.tenant_name)
    Current.reset
    Current.acp = acp
  end

  def self.seasons; SEASONS end
  def self.languages; LANGUAGES end
  def self.features; FEATURES end
  def self.feature_flags; FEATURE_FLAGS end
  def self.billing_year_divisions; BILLING_YEAR_DIVISIONS end
  def self.activity_i18n_scopes; ACTIVITY_I18N_SCOPES end

  def feature?(feature)
    features.include?(feature.to_s)
  end

  def feature_flag?(feature)
    feature_flags.include?(feature.to_s)
  end

  def recurring_billing?
    !!recurring_billing_wday
  end

  def billing_year_divisions=(divisions)
    super divisions.map(&:to_i) & BILLING_YEAR_DIVISIONS
  end

  def invoice_type
    ccp? ? 'ISR' : 'QR'
  end

  def isr_invoice?
    invoice_type == 'ISR'
  end

  def qr_invoice?
    invoice_type == 'QR'
  end

  def languages=(languages)
    super languages & LANGUAGES
  end

  def languages
    super & LANGUAGES
  end

  def email_from
    "#{name} #{email_default_from}"
  end

  def url=(url)
    super
    self.host ||= PublicSuffix.parse(URI(url).host).sld
  end

  def phone=(phone)
    super
    self.activity_phone ||= phone
  end

  def current_fiscal_year
    FiscalYear.current(start_month: fiscal_year_start_month)
  end

  def fiscal_year_for(date_or_year)
    FiscalYear.for(date_or_year, start_month: fiscal_year_start_month)
  end

  def fy_month_for(date)
    fiscal_year_for(date).month(date)
  end

  def summer_month_range_min
    @summer_month_range_min&.to_i || summer_month_range&.min
  end

  def summer_month_range_max
    @summer_month_range_max&.to_i || summer_month_range&.max
  end

  def annual_fee?
    annual_fee&.positive?
  end

  def share?
    share_price&.positive?
  end

  def seasons?
    summer_month_range?
  end

  def ical_feed?
    ical_feed_auth_token.present?
  end

  def ical_feed_auth_token
    credentials(:icalendar_auth_token)
  end

  def season_for(month)
    raise 'winter/summer seasons not configured' unless seasons?
    raise ArgumentError, 'not a month (1..12)' unless month.in? 1..12

    summer_month_range.include?(month) ? 'summer' : 'winter'
  end

  def credentials(*keys)
    Rails.application.credentials.dig(tenant_name.to_sym, *keys)
  end

  def ragedevert?
    tenant_name == 'ragedevert'
  end

  def tapatate?
    tenant_name == 'tapatate'
  end

  def group_buying_email
    self[:group_buying_email] || email
  end

  def create_tenant
    Apartment::Tenant.create(tenant_name)
  end

  def set_summer_month_range
    if @summer_month_range_min && @summer_month_range_max
      self.summer_month_range =
        if @summer_month_range_min.present? && @summer_month_range_max.present?
          @summer_month_range_min..@summer_month_range_max
        else
          nil
        end
    end
  end
end
