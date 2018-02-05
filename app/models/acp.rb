class ACP < ActiveRecord::Base
  FEATURES = %w[
    basket_content
    gribouille
  ]

  validates :name, presence: true
  validates :host, presence: true
  validates :tenant_name, presence: true
  validates :fiscal_year_start_month,
    presence: true,
    inclusion: { in: 1..12 }
  validates :trial_basket_count, numericality: { greater_than_or_equal_to: 0 }
  validates :support_price, numericality: { greater_than_or_equal_to: 0 }

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

  def feature?(feature)
    self.features.include?(feature.to_s)
  end

  def current_fiscal_year
    FiscalYear.current(start_month: fiscal_year_start_month)
  end

  def fiscal_year_for(date_or_year)
    FiscalYear.for(date_or_year, start_month: fiscal_year_start_month)
  end

  private

  def create_tenant
    Apartment::Tenant.create(tenant_name)
  end
end
