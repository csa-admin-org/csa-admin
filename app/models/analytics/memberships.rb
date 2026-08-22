# frozen_string_literal: true

class Analytics::Memberships
  include Analytics::Series

  def self.available? = Membership.exists?
  def self.icon = "calendar-range"

  Year = Data.define(
    :fiscal_year,
    :count,
    :new_count,
    :returning_count,
    :renewal_rate,
    :early_exit_count,
    :average_price,
    :median_price,
    :size_quantities,
    :complement_quantities,
    :depot_quantities,
    :delivery_cycle_quantities,
    :billing_year_divisions,
    :extra_counts
  ) do
    include Analytics::Year
  end

  def sizes
    @sizes ||= catalog(BasketSize, series.flat_map { |year| year.size_quantities.keys })
  end

  def complements
    @complements ||= catalog(BasketComplement, series.flat_map { |year| year.complement_quantities.keys })
  end

  def depots
    @depots ||= begin
      by_id = Depot.unscoped.where(id: depot_ids).index_by(&:id)
      depot_ids.filter_map { |id| by_id[id] && [ id, by_id[id] ] }.to_h
    end
  end

  def delivery_cycles
    @delivery_cycles ||= catalog(DeliveryCycle, series.flat_map { |year| year.delivery_cycle_quantities.keys })
  end

  def billing_year_divisions
    @billing_year_divisions ||= series
      .flat_map { |year| year.billing_year_divisions.keys }
      .uniq
      .sort
  end

  def complements?
    complements.any?
  end

  def depots?
    depots.size > 1
  end

  def depots_capped? = all_depot_ids.size > Analytics::PALETTE_SIZE

  def delivery_cycles?
    delivery_cycles.size > 1
  end

  def billing_year_divisions?
    billing_year_divisions.size > 1
  end

  def early_exits?
    series.any? { |year| year.early_exit_count.positive? }
  end

  def extras
    @extras ||= series.flat_map { |year|
      year.extra_counts.select { |_extra, count| count.positive? }.keys
    }.uniq.sort
  end

  def extras?
    extras.size > 1 && extras.size <= Analytics::PALETTE_SIZE
  end

  def charts
    [].tap do |panels|
      panels << chart.stacked_area(
        "memberships", I18n.t("analytics.charts.memberships"), self.class.icon,
        [
          [ I18n.t("analytics.metrics.new"), series.map(&:new_count) ],
          [ I18n.t("analytics.metrics.renewal"), series.map(&:returning_count) ]
        ])
      if early_exits?
        panels << chart.grouped_bar(
          "early-exits", I18n.t("analytics.charts.early_exits"), "calendar-x",
          [ [ I18n.t("analytics.metrics.early_exits"), series.map(&:early_exit_count) ] ])
      end
      if sizes.any?
        panels << chart.mix_area(
          "size-mix", size_mix_title, "shopping-bag", sizes,
          ->(year, id) { year.size_quantities[id].to_i })
      end
      if complements?
        panels << chart.mix_area(
          "complements", BasketComplement.model_name.human(count: 2), "circle-plus", complements,
          ->(year, id) { year.complement_quantities[id].to_i })
      end
      if depots?
        panels << chart.mix_area(
          "depots", depots_title, "map", depots,
          ->(year, id) { year.depot_quantities[id].to_i },
          share_totals: depot_share_totals)
      end
      if delivery_cycles?
        panels << chart.mix_area(
          "delivery-cycles", DeliveryCycle.model_name.human(count: 2), "calendar-cog", delivery_cycles,
          ->(year, id) { year.delivery_cycle_quantities[id].to_i })
      end
      if billing_year_divisions?
        panels << chart.stacked_area(
          "billing-year-division", Membership.human_attribute_name(:billing_year_division), "calendar-sync",
          billing_year_divisions.map { |division|
            [ I18n.t("billing.year_division.x#{division}"), series.map { |year| year.billing_year_divisions[division].to_i } ]
          })
      end
      if extras?
        panels << chart.stacked_area(
          "price-extra-mix", Current.org.basket_price_extra_title, "coins",
          extras.map { |extra|
            [ extra_label(extra), series.map { |year| year.extra_counts[extra].to_i } ]
          })
      end
      if series.any? { |year| year.average_price || year.median_price }
        panels << chart.line(
          "prices", I18n.t("analytics.charts.prices"), "receipt-text",
          [
            [ I18n.t("analytics.metrics.average_price"), series.map { |year| decimal_or_nil(year.average_price) } ],
            [ I18n.t("analytics.metrics.median_price"), series.map { |year| decimal_or_nil(year.median_price) } ]
          ],
          currency: true)
      end
    end
  end

  def headlines
    [
      headline(I18n.t("analytics.metrics.memberships"), series.map(&:count)),
      headline(I18n.t("analytics.metrics.new"), series.map(&:new_count)),
      headline(I18n.t("analytics.metrics.renewal_rate"), series.map { |year| format_percentage(year.renewal_rate) }),
      headline(currency_title(I18n.t("analytics.metrics.average_price")), series.map { |year| format_currency(year.average_price) })
    ]
  end

  private

  def size_mix_title
    I18n.t("analytics.charts.size_mix")
  end

  def depots_title
    top_n_title(Depot.model_name.human(count: 2), all_depot_ids.size)
  end

  def extra_label(extra)
    extra.to_d.zero? ? I18n.t("analytics.metrics.no_extra") : cur(extra)
  end

  MembershipRow = Data.define(
    :id,
    :member_id,
    :started_on,
    :ended_on,
    :renewed_at,
    :price,
    :basket_size_id,
    :basket_size_price,
    :basket_quantity,
    :depot_id,
    :delivery_cycle_id,
    :billing_year_division,
    :basket_price_extra,
    :salary_basket)

  ComplementRow = Data.define(
    :membership_id,
    :basket_complement_id,
    :quantity,
    :price)

  def rows
    @rows ||= Membership.joins("INNER JOIN members ON members.id = memberships.member_id").pluck(
      :id,
      :member_id,
      :started_on,
      :ended_on,
      :renewed_at,
      :price,
      :basket_size_id,
      :basket_size_price,
      :basket_quantity,
      :depot_id,
      :delivery_cycle_id,
      :billing_year_division,
      :basket_price_extra,
      "members.salary_basket"
    ).map { |values| MembershipRow.new(*values) }
  end

  def complement_rows
    @complement_rows ||= MembershipsBasketComplement.pluck(
      :membership_id,
      :basket_complement_id,
      :quantity,
      :price
    ).map { |values| ComplementRow.new(*values) }
  end

  def complements_by_membership
    @complements_by_membership ||= complement_rows.group_by(&:membership_id)
  end

  def first_started_on_by_member
    @first_started_on_by_member ||= rows
      .group_by(&:member_id)
      .transform_values { |memberships| memberships.map(&:started_on).min }
  end

  def rows_by_year
    @rows_by_year ||= begin
      grouped = Hash.new { |hash, year| hash[year] = [] }
      rows.each do |row|
        year = Analytics.year_for(row.started_on)
        next unless year == Analytics.year_for(row.ended_on)

        grouped[year] << row
      end
      grouped
    end
  end

  def build_year(fiscal_year)
    memberships = during(fiscal_year)
    firsts = first_started_on_by_member
    new_count = memberships.count { |row| firsts[row.member_id] == row.started_on }
    count = memberships.size
    renewed_count = memberships.count { |row| row.renewed_at.present? }
    prices = billable_prices(memberships)
    billable = billable_memberships(memberships)

    Year.new(
      fiscal_year: fiscal_year,
      count: count,
      new_count: new_count,
      returning_count: count - new_count,
      renewal_rate: rate_for(fiscal_year, count, renewed_count, closed: true),
      early_exit_count: memberships.count { |row| row.ended_on < fiscal_year.end_of_year },
      average_price: average_for(prices),
      median_price: Analytics.percentile(prices, 50),
      size_quantities: size_quantities_for(memberships),
      complement_quantities: complement_quantities_for(memberships),
      depot_quantities: quantity_by(memberships, :depot_id),
      delivery_cycle_quantities: quantity_by(memberships, :delivery_cycle_id),
      billing_year_divisions: memberships
        .group_by(&:billing_year_division)
        .transform_values(&:size),
      extra_counts: extra_counts_for(billable))
  end

  def billable_memberships(memberships)
    memberships.reject(&:salary_basket)
  end

  def billable_prices(memberships)
    billable_memberships(memberships)
      .reject { |row| row.price.to_d <= 0 }
      .map { |row| row.price.to_d }
  end

  def average_for(prices)
    return if prices.empty?

    prices.sum / prices.size
  end

  def size_quantities_for(memberships)
    quantity_by(memberships, :basket_size_id)
  end

  def complement_quantities_for(memberships)
    quantities = Hash.new(0)
    memberships.each do |membership|
      complements_by_membership.fetch(membership.id, []).each do |row|
        next if row.price.to_d <= 0

        quantities[row.basket_complement_id] += row.quantity.to_i
      end
    end
    quantities
  end

  def all_depot_ids
    @all_depot_ids ||= series.flat_map { |year| year.depot_quantities.keys }.uniq
  end

  def depot_ids
    @depot_ids ||= begin
      totals = Hash.new(0)
      ranked_years = series.reject(&:in_progress?)
      ranked_years = series if ranked_years.empty?
      ranked_years.each do |year|
        year.depot_quantities.each { |id, quantity| totals[id] += quantity.to_i }
      end
      totals.sort_by { |_id, quantity| -quantity }.first(Analytics::PALETTE_SIZE).map(&:first)
    end
  end

  def depot_share_totals
    series.map { |year| year.depot_quantities.values.sum }
  end

  def extra_counts_for(memberships)
    memberships
      .group_by { |row| snap_extra(row.basket_price_extra) }
      .transform_values(&:size)
  end

  def extra_catalog
    @extra_catalog ||= (Array(Current.org[:basket_price_extras]).map(&:to_d) + [ 0.to_d ]).uniq
  end

  def snap_extra(value)
    extra = value.to_d
    extra_catalog.min_by { |candidate| (candidate - extra).abs }
  end

  def quantity_by(memberships, attribute)
    memberships
      .group_by(&attribute)
      .transform_values { |rows| rows.sum { |row| row.basket_quantity.to_i } }
  end
end
