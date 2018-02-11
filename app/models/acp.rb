class ACP < ActiveRecord::Base
  FEATURES = %w[
    basket_content
    gribouille
  ]
  SEASONS = %w[summer winter]

  attr_accessor :summer_month_range_min, :summer_month_range_max

  validates :name, presence: true
  validates :host, presence: true
  validates :tenant_name, presence: true
  validates :fiscal_year_start_month,
    presence: true,
    inclusion: { in: 1..12 }
  validates :trial_basket_count, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :support_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :summer_month_range_min,
    inclusion: { in: 1..12 },
    if: -> { @summer_month_range_max.present? }
  validates :summer_month_range_max,
    inclusion: { in: 1..12 },
    numericality: { greater_than_or_equal_to: ->(acp) { acp.summer_month_range_min } },
    if: -> { @summer_month_range_min.present? }

  before_save :set_summer_month_range
  after_create :create_tenant

  def self.switch_each!
    ACP.pluck(:tenant_name).each do |tenant|
      Apartment::Tenant.switch!(tenant)
      Current.acp = nil
      yield
    end
  ensure
    Apartment::Tenant.reset
  end

  def self.seasons; SEASONS end

  def feature?(feature)
    self.features.include?(feature.to_s)
  end

  def current_fiscal_year
    FiscalYear.current(start_month: fiscal_year_start_month)
  end

  def fiscal_year_for(date_or_year)
    FiscalYear.for(date_or_year, start_month: fiscal_year_start_month)
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
