module AcpsHelper
  def feature?(feature)
    Current.acp.feature?(feature)
  end

  def fiscal_year_range
    fy = Current.acp.current_fiscal_year
    range =
      if fy.range.min.year == fy.range.max.year
        [
          l(fy.range.min, format: '%b'),
          l(fy.range.max, format: '%b %Y')
        ]
      else
        [
          l(fy.range.min, format: '%b %Y'),
          l(fy.range.max, format: '%b %Y')
        ]
      end
    range.join(' - ')
  end

  def link_to_acp_website
    link_to Current.acp.url.sub(/https?:\/\//, ''), Current.acp.url
  end
end
