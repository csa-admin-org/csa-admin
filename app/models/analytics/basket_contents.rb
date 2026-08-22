# frozen_string_literal: true

class Analytics::BasketContents
  include Analytics::Series

  def self.available?
    return false unless Current.org.feature?(:basket_content)

    range = Analytics.past_date_range
    return false unless range

    BasketContent.joins(:delivery).where(deliveries: { date: range }).exists?
  end

  def self.icon = "sprout"
  def self.page_id = :basket_content

  Year = Data.define(
    :fiscal_year,
    :count,
    :unfilled_count,
    :coverage_rate,
    :product_count,
    :median_content_value,
    :size_values,
    :size_price_gaps,
    :product_counts
  ) do
    include Analytics::Year
  end

  def content_value?
    series.any? { |year| year.size_values.any? { |_id, value| value } }
  end

  def sizes
    @sizes ||= catalog(BasketSize, series.flat_map { |year| year.size_values.keys })
  end

  def products
    @products ||= begin
      totals = Hash.new(0)
      series.each do |year|
        year.product_counts.each { |id, count| totals[id] += count }
      end
      ids = totals.sort_by { |_id, count| -count }.first(Analytics::PALETTE_SIZE).map(&:first)
      return {} if ids.size < 2

      by_id = BasketContent::Product.unscoped.where(id: ids).index_by(&:id)
      ids.filter_map { |id| by_id[id] && [ id, by_id[id] ] }.to_h
    end
  end

  def products?
    products.size >= 2
  end

  def price_gap?
    series.any? { |year| year.size_price_gaps.any? { |_id, value| value } }
  end

  def charts
    [].tap do |panels|
      panels << chart.stacked_area(
        "filled-deliveries", I18n.t("analytics.charts.filled_deliveries"), "calendar",
        [
          [ I18n.t("analytics.metrics.filled_deliveries"), series.map(&:count) ],
          [ I18n.t("analytics.metrics.unfilled_deliveries"), series.map(&:unfilled_count) ]
        ])
      if products?
        panels << chart.stacked_area(
          "top-products", top_products_title, "sprout",
          products.map { |id, product|
            [ product.name, series.map { |year| year.product_counts[id].to_i } ]
          },
          share_totals: series.map { |year| year.product_counts.values.sum })
      end
      if content_value?
        panels << chart.line(
          "content-value", I18n.t("analytics.charts.content_value"), "receipt-text",
          sizes.values.map { |size|
            [ size.display_name, series.map { |year| decimal_or_nil(year.size_values[size.id]) } ]
          },
          currency: true)
      end
      if price_gap?
        panels << chart.signed_rate_line(
          "content-price-gap", I18n.t("analytics.charts.content_price_gap"), "scale",
          sizes.values.map { |size|
            [ size.display_name, series.map { |year| decimal_or_nil(year.size_price_gaps[size.id]) } ]
          })
      end
    end
  end

  def headlines
    [
      headline(I18n.t("analytics.metrics.filled_deliveries"), series.map(&:count)),
      headline(I18n.t("analytics.metrics.coverage_rate"), series.map { |year| format_percentage(year.coverage_rate) }),
      headline(I18n.t("analytics.metrics.products"), series.map(&:product_count)),
      if series.any? { |year| year.median_content_value }
        headline(currency_title(I18n.t("analytics.metrics.median_content_value")),
          series.map { |year| format_currency(year.median_content_value) })
      end
    ].compact
  end

  private

  DeliveryRow = Data.define(:date, :filled, :product_ids, :avg_prices, :price_percentage)

  def rows
    @rows ||= begin
      contents = BasketContent.pluck(:delivery_id, :product_id).group_by(&:first)
      Delivery.pluck(:id, :date, :basket_content_avg_prices, :basket_size_price_percentage).map { |id, date, prices, percentage|
        products = (contents[id] || []).map(&:last)
        DeliveryRow.new(date, products.any?, products.uniq, prices || {}, percentage)
      }
    end
  end

  def rows_by_year
    @rows_by_year ||= group_by_year(rows)
  end

  def build_year(fiscal_year)
    deliveries = during(fiscal_year)
    past = deliveries.reject { |row| row.date.future? }
    filled = past.select(&:filled)
    unfilled = past.size - filled.size
    prices = filled.flat_map { |row| row.avg_prices.values.map(&:to_d) }.reject(&:zero?)

    Year.new(
      fiscal_year: fiscal_year,
      count: filled.size,
      unfilled_count: unfilled,
      coverage_rate: rate_for(fiscal_year, past.size, filled.size),
      product_count: filled.flat_map(&:product_ids).uniq.size,
      median_content_value: Analytics.percentile(prices, 50),
      size_values: size_values_for(filled),
      size_price_gaps: size_price_gaps_for(filled, fiscal_year),
      product_counts: product_counts_for(filled))
  end

  def size_values_for(deliveries)
    prices_by_size = Hash.new { |hash, id| hash[id] = [] }
    deliveries.each do |row|
      row.avg_prices.each do |size_id, price|
        next if price.to_d.zero?

        prices_by_size[size_id.to_i] << price.to_d
      end
    end
    prices_by_size.transform_values { |prices| Analytics.percentile(prices, 50) }
  end

  def size_price_gaps_for(deliveries, fiscal_year)
    gaps_by_size = Hash.new { |hash, id| hash[id] = [] }
    deliveries.each do |row|
      row.avg_prices.each do |size_id, price|
        next if price.to_d.zero?

        planned = planned_price_for(fiscal_year, size_id.to_i, row.price_percentage)
        next unless planned.positive?

        gaps_by_size[size_id.to_i] << ((price.to_d - planned) * 100.0 / planned)
      end
    end
    gaps_by_size.transform_values { |gaps| Analytics.percentile(gaps, 50) }
  end

  def planned_price_for(fiscal_year, size_id, percentage)
    base = planned_prices.dig(fiscal_year.year, size_id).to_d
    return 0 unless base.positive?
    return base if percentage.nil?

    (base * percentage / 100.0).round_to_one_cent
  end

  def planned_prices
    @planned_prices ||= planned_price_counts.transform_values { |sizes|
      sizes.transform_values { |prices| prices.max_by(&:last)&.first || 0 }
    }
  end

  def planned_price_counts
    counts = Hash.new { |years, year| years[year] = Hash.new { |sizes, id| sizes[id] = Hash.new(0) } }
    range = Analytics.date_range
    return counts unless range

    Basket.joins(:delivery)
      .where(deliveries: { date: range, basket_size_price_percentage: nil })
      .pluck("deliveries.date", :basket_size_id, :basket_size_price)
      .each { |date, id, price| counts[Analytics.year_for(date)][id][price] += 1 }
    counts
  end

  def product_counts_for(deliveries)
    counts = Hash.new(0)
    deliveries.each do |row|
      row.product_ids.uniq.each { |id| counts[id] += 1 }
    end
    counts
  end

  def top_products_title
    top_n_title(I18n.t("analytics.charts.top_products"), all_product_ids.size)
  end

  def all_product_ids
    @all_product_ids ||= series.flat_map { |year| year.product_counts.keys }.uniq
  end
end
