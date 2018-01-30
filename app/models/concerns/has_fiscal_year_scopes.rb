module HasFiscalYearScopes
  extend ActiveSupport::Concern

  included do
    delegate :year, :range, to: :fiscal_year, prefix: :fy

    scope :current_year, -> { where(date: Current.fy_range) }
    scope :during_year, ->(year) { where(date: Current.acp.fiscal_year_for(year).range) }
    scope :past_year, -> { where("#{table_name}.date < ?", Current.fy_range.min) }
    scope :future_year, -> { where("#{table_name}.date > ?", Current.fy_range.max) }
  end

  def fiscal_year
    Current.acp.fiscal_year_for(date)
  end

  def current_year?
    fy_year == Current.fy_year
  end
end
