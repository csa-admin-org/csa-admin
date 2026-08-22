# frozen_string_literal: true

class Analytics::Shop
  include Analytics::Series

  def self.available?
    return false unless Current.org.feature?(:shop)

    range = Analytics.past_date_range
    return false unless range

    invoiced = ::Shop::Order.invoiced
    return true if invoiced.where(delivery_type: "Delivery", delivery_id: Delivery.where(date: range)).exists?

    invoiced.where(
      delivery_type: "Shop::SpecialDelivery",
      delivery_id: ::Shop::SpecialDelivery.where(date: range)).exists?
  end

  def self.icon = "shopping-basket"

  Year = Data.define(
    :fiscal_year,
    :count,
    :amount,
    :member_count,
    :average_amount,
    :variant_quantities
  ) do
    include Analytics::Year
  end

  def variants
    @variants ||= begin
      totals = Hash.new(0)
      series.each do |year|
        year.variant_quantities.each { |key, quantity| totals[key] += quantity }
      end
      keys = totals.sort_by { |_key, quantity| -quantity }.first(Analytics::PALETTE_SIZE).map(&:first)
      return {} if keys.size < 2

      product_ids = keys.map(&:first).uniq
      variant_ids = keys.map(&:last).uniq
      products = ::Shop::Product.unscoped.where(id: product_ids).index_by(&:id)
      variants_by_id = ::Shop::ProductVariant.unscoped.where(id: variant_ids).index_by(&:id)
      keys.filter_map { |product_id, variant_id|
        product = products[product_id]
        variant = variants_by_id[variant_id]
        next unless product && variant

        [ [ product_id, variant_id ], [ product, variant ] ]
      }.to_h
    end
  end

  def variants?
    variants.size >= 2
  end

  def charts
    [].tap do |panels|
      panels << chart.grouped_bar(
        "shop-amounts", I18n.t("analytics.charts.shop_amounts"), self.class.icon,
        [ [ I18n.t("analytics.metrics.delivered"), series.map { |year| decimal_or_nil(year.amount) } ] ],
        currency: true)
      panels << chart.grouped_bar(
        "shop-orders", I18n.t("analytics.charts.shop_orders"), "users",
        [
          [ I18n.t("analytics.metrics.shop_orders"), series.map(&:count) ],
          [ I18n.t("analytics.metrics.shop_members"), series.map(&:member_count) ]
        ])
      panels << chart.line(
        "shop-average", I18n.t("analytics.charts.shop_average"), "receipt-text",
        [ [ I18n.t("analytics.metrics.average_order"), series.map { |year| decimal_or_nil(year.average_amount) } ] ],
        currency: true)
      if variants?
        panels << chart.stacked_area(
          "shop-products", shop_products_title, self.class.icon,
          variants.map { |key, records|
            product, variant = records
            [ [ product.name, variant.name ].join(" · "), series.map { |year| year.variant_quantities[key].to_i } ]
          },
          share_totals: series.map { |year| year.variant_quantities.values.sum })
      end
    end
  end

  def headlines
    [
      headline(currency_title(I18n.t("analytics.metrics.delivered")), series.map { |year| format_currency(year.amount) }),
      headline(I18n.t("analytics.metrics.shop_orders"), series.map(&:count)),
      headline(I18n.t("analytics.metrics.shop_members"), series.map(&:member_count)),
      headline(currency_title(I18n.t("analytics.metrics.average_order")), series.map { |year| format_currency(year.average_amount) })
    ]
  end

  private

  OrderRow = Data.define(:date, :member_id, :amount)
  ItemRow = Data.define(:date, :product_id, :variant_id, :quantity)

  def rows
    @rows ||= invoiced_orders.pluck(:member_id, :amount, :delivery_type, :delivery_id).filter_map { |member_id, amount, type, id|
      date = delivered_date(type, id)
      OrderRow.new(date, member_id, amount) if date
    }
  end

  def item_rows
    @item_rows ||= begin
      order_dates = invoiced_orders.pluck(:id, :delivery_type, :delivery_id).filter_map { |id, type, delivery_id|
        date = delivered_date(type, delivery_id)
        [ id, date ] if date
      }.to_h
      ::Shop::OrderItem.where(order_id: order_dates.keys).pluck(
        :order_id, :product_id, :product_variant_id, :quantity
      ).filter_map { |order_id, product_id, variant_id, quantity|
        date = order_dates[order_id]
        ItemRow.new(date, product_id, variant_id, quantity) if date
      }
    end
  end

  def invoiced_orders
    @invoiced_orders ||= ::Shop::Order.invoiced
  end

  def delivered_date(type, id)
    date = delivery_dates.dig(type, id)
    date unless date&.future?
  end

  def delivery_dates
    @delivery_dates ||= {
      "Delivery" => Delivery.where(id: invoiced_orders.where(delivery_type: "Delivery").select(:delivery_id)).pluck(:id, :date).to_h,
      "Shop::SpecialDelivery" => ::Shop::SpecialDelivery.where(id: invoiced_orders.where(delivery_type: "Shop::SpecialDelivery").select(:delivery_id)).pluck(:id, :date).to_h
    }
  end

  def rows_by_year
    @rows_by_year ||= group_by_year(rows)
  end

  def items_by_year
    @items_by_year ||= group_by_year(item_rows)
  end

  def build_year(fiscal_year)
    orders = during(fiscal_year)
    amount = orders.sum { |row| row.amount.to_d }
    count = orders.size
    items = items_by_year[fiscal_year.year] || []

    Year.new(
      fiscal_year: fiscal_year,
      count: count,
      amount: amount,
      member_count: orders.map(&:member_id).uniq.size,
      average_amount: count.positive? ? amount / count : nil,
      variant_quantities: variant_quantities_for(items))
  end

  def variant_quantities_for(items)
    quantities = Hash.new(0)
    items.each do |row|
      quantities[[ row.product_id, row.variant_id ]] += row.quantity.to_i
    end
    quantities
  end

  def shop_products_title
    top_n_title(I18n.t("analytics.charts.shop_products"), all_variant_keys.size)
  end

  def all_variant_keys
    @all_variant_keys ||= series.flat_map { |year| year.variant_quantities.keys }.uniq
  end
end
