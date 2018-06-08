class ACP < ActiveRecord::Base
  FEATURES = %w[
    basket_content
    recurring_billing
  ]
  LANGUAGES = %w[fr de]
  SEASONS = %w[summer winter]
  BILLING_YEAR_DIVISIONS = [1, 2, 3, 4, 12]
  HALFDAY_I18N_SCOPES = %w[halfday_work basket_preparation]
  HALFDAY_PRICE = 60

  attr_accessor :summer_month_range_min, :summer_month_range_max

  has_one_attached :logo

  validates :name, presence: true
  validates :host, presence: true
  validates :url, presence: true
  validates :email, presence: true
  validates :phone, presence: true
  validates :ccp, presence: true
  validates :isr_identity, presence: true
  validates :isr_payment_for, presence: true
  validates :isr_in_favor_of, presence: true
  validates :invoice_info, presence: true
  validates :invoice_footer, presence: true
  validates :tenant_name, presence: true
  validates :fiscal_year_start_month,
    presence: true,
    inclusion: { in: 1..12 }
  validates :trial_basket_count, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :support_price, numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :summer_month_range_min,
    inclusion: { in: 1..12 },
    if: -> { @summer_month_range_max.present? }
  validates :summer_month_range_max,
    inclusion: { in: 1..12 },
    numericality: { greater_than_or_equal_to: ->(acp) { acp.summer_month_range_min } },
    if: -> { @summer_month_range_min.present? }
  validates :halfday_i18n_scope, inclusion: { in: HALFDAY_I18N_SCOPES }
  validates :halfday_participation_deletion_deadline_in_days,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validates :vat_number, presence: true, if: -> { vat_membership_rate&.positive? }
  validates :vat_membership_rate, numericality: { greater_than: 0 }, if: :vat_number?

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
  def self.billing_year_divisions; BILLING_YEAR_DIVISIONS end
  def self.halfday_i18n_scopes; HALFDAY_I18N_SCOPES end

  def feature?(feature)
    self.features.include?(feature.to_s)
  end

  def billing_year_divisions=(divisions)
    super divisions.map(&:to_i) & BILLING_YEAR_DIVISIONS
  end

  def languages=(languages)
    super languages & LANGUAGES
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

  def seasons?
    summer_month_range?
  end

  def season_for(month)
    raise 'winter/summer seasons not configured' unless seasons?
    raise ArgumentError, 'not a month (1..12)' unless month.in? 1..12
    summer_month_range.include?(month) ? 'summer' : 'winter'
  end

  def credentials(key)
    Rails.application.credentials.dig(tenant_name.to_sym, key)
  end

  private

  def create_tenant
    Apartment::Tenant.create(tenant_name)
  end

  def set_summer_month_range
    if @summer_month_range_min && @summer_month_range_max
      if @summer_month_range_min.present? && @summer_month_range_max.present?
        self.summer_month_range =
          @summer_month_range_min..@summer_month_range_max
      else
        self.summer_month_range = nil
      end
    end
  end
end
