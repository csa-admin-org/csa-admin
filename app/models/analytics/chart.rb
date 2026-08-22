# frozen_string_literal: true

class Analytics::Chart
  Panel = Data.define(:id, :title, :icon, :config)

  def initialize(page)
    @page = page
    @labels = page.series.map { |year| year.fiscal_year.to_s }
  end

  def stacked_area(id, title, icon, datasets, share_totals: nil)
    panel(id, title, icon, "line", area_datasets(datasets), stacked_area_options(share_totals:))
  end

  def stacked_bar(id, title, icon, datasets, currency: false, share_totals: nil)
    panel(id, title, icon, "bar", stacked_datasets(datasets), bar_options(stacked: true, currency:, share_totals:))
  end

  def grouped_bar(id, title, icon, datasets, currency: false)
    panel(id, title, icon, "bar", grouped_datasets(datasets), bar_options(stacked: false, currency: currency))
  end

  def line(id, title, icon, datasets, currency: false, percentage: false, max: :auto)
    panel(id, title, icon, "line", line_datasets(datasets),
      line_options(currency: currency, percentage: percentage, max: max))
  end

  def rate_line(id, title, icon, datasets)
    values = datasets.flat_map(&:last)
    line(id, title, icon, datasets, percentage: true, max: tens_axis_max(values))
  end

  def signed_rate_line(id, title, icon, datasets)
    line(id, title, icon, datasets, percentage: true, max: :none)
  end

  def mix_area(id, title, icon, catalog, value_for, share_totals: nil)
    stacked_area(id, title, icon, catalog.values.map { |record|
      [ record.display_name, @page.series.map { |year| value_for.call(year, record.id) } ]
    }, share_totals:)
  end

  private

  def panel(id, title, icon, type, datasets, options)
    Panel.new(id, title, icon, { type: type, data: { labels: @labels, datasets: datasets }, options: options })
  end

  def stacked_datasets(rows)
    rows.each_with_index.map { |(label, data), index| stacked_dataset(label, data, index) }
  end

  def grouped_datasets(rows)
    rows.each_with_index.map { |(label, data), index| grouped_dataset(label, data, index) }
  end

  def line_datasets(rows)
    rows.each_with_index.map { |(label, data), index| line_dataset(label, data, index) }
  end

  def area_datasets(rows)
    rows.each_with_index.map { |(label, data), index| area_dataset(label, data, index) }
  end

  def stacked_dataset(label, data, index)
    {
      label: label,
      data: data,
      backgroundColor: palette_color(index, 0.8),
      hoverBackgroundColor: palette_color(index, 1),
      borderWidth: 0,
      stack: "stack"
    }
  end

  def grouped_dataset(label, data, index)
    stacked_dataset(label, data, index).except(:stack)
  end

  def line_dataset(label, data, index)
    {
      label: label,
      data: data,
      borderColor: palette_color(index, 1),
      backgroundColor: palette_color(index, 0.15),
      pointBackgroundColor: palette_color(index, 1),
      pointRadius: 3,
      pointHoverRadius: 5,
      clip: false,
      tension: 0.25,
      fill: false,
      spanGaps: false
    }
  end

  def area_dataset(label, data, index)
    {
      label: label,
      data: data,
      borderColor: palette_color(index, 1),
      backgroundColor: palette_color(index, 0.5),
      pointBackgroundColor: palette_color(index, 1),
      pointRadius: 0,
      pointHoverRadius: 4,
      clip: false,
      borderWidth: 1.5,
      tension: 0.25,
      fill: index.zero? ? "origin" : "-1",
      spanGaps: true
    }
  end

  def chart_base_options(share_totals: nil)
    {
      responsive: true,
      maintainAspectRatio: false,
      clip: false,
      defaultYearIndex: @page.default_year_index,
      openYearIndex: @page.open_year_index,
      currencyCode: Current.org.currency_code,
      numberDelimiter: I18n.t("number.format.delimiter"),
      numberSeparator: I18n.t("number.format.separator"),
      layout: { padding: { top: 8, bottom: 4, left: 0, right: 4 } },
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "bottom",
          labels: {
            boxWidth: 10,
            padding: 12
          }
        }
      }
    }.tap { |options| options[:shareTotals] = share_totals if share_totals }
  end

  def bar_options(stacked:, currency: false, percentage: false, share_totals: nil)
    options = chart_base_options(share_totals:)
    options[:scales] = {
      x: {
        stacked: stacked,
        offset: true,
        grid: { display: false },
        ticks: {
          major: { enabled: true },
          autoSkip: true,
          maxRotation: 45,
          minRotation: 0
        }
      },
      y: {
        stacked: stacked,
        beginAtZero: true,
        max: percentage ? 100 : nil,
        ticks: { currency: currency, percentage: percentage }
      }.compact
    }
    options
  end

  def line_options(currency: false, percentage: false, max: :auto)
    options = chart_base_options
    options[:scales] = {
      x: {
        offset: false,
        grid: { display: false },
        ticks: {
          major: { enabled: true },
          autoSkip: true,
          maxRotation: 45,
          minRotation: 0
        }
      },
      y: {
        beginAtZero: true,
        max: axis_max(percentage, max),
        ticks: { currency: currency, percentage: percentage }
      }.compact
    }
    options
  end

  def stacked_area_options(share_totals: nil)
    options = chart_base_options(share_totals:)
    options[:scales] = {
      x: {
        offset: false,
        grid: { display: false },
        ticks: {
          major: { enabled: true },
          autoSkip: true,
          maxRotation: 45,
          minRotation: 0
        }
      },
      y: { stacked: true, beginAtZero: true }
    }
    options
  end

  def axis_max(percentage, max)
    case max
    when :auto then percentage ? 100 : nil
    when :none then nil
    else max
    end
  end

  def tens_axis_max(values)
    peak = values.compact.max
    return 10 unless peak&.positive?

    tens = (peak / 10.0).ceil * 10
    [ tens, 100 ].min
  end

  def palette_color(index, alpha)
    red, green, blue = Analytics::PALETTE[index % Analytics::PALETTE.size]
    "rgba(#{red}, #{green}, #{blue}, #{alpha})"
  end
end
