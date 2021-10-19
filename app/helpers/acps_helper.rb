module AcpsHelper
  def feature?(feature)
    Current.acp.feature?(feature)
  end

  def fiscal_year_months_range
    Current.acp.current_fiscal_year
      .range.minmax
      .map { |d| l(d, format: '%B') }
      .join(' – ')
  end

  def link_to_acp_website(options = {})
    link_to Current.acp.url.sub(/https?:\/\//, ''), Current.acp.url, options
  end
end
