class DeliveryCycle < ApplicationRecord
  include TranslatedAttributes

  MEMBER_ORDER_MODES = %w[
    name_asc
    deliveries_count_asc
    deliveries_count_desc
    wdays_asc
  ]
  CONFIGURATION_ATTRIBUTES = %w[
    wdays
    months
    week_numbers
    results
    minimum_gap_in_days
  ]

  enum week_numbers: %i[all odd even], _suffix: true
  enum results: %i[
    all
    odd even
    quarter_1 quarter_2 quarter_3 quarter_4
    all_but_first
    first_of_each_month
    last_of_each_month
  ], _suffix: true

  has_many :memberships
  has_many :memberships_basket_complements
  has_many :basket_sizes

  has_and_belongs_to_many :depots # Visibility

  translated_attributes :public_name
  translated_attributes :name, required: true

  default_scope { order_by_name }

  scope :visible, -> {
    unscoped.joins(:depots).merge(Depot.unscoped.visible).distinct
  }

  validates :minimum_gap_in_days,
    numericality: {
      greater_than_or_equal_to: 1,
      only_integer: true,
      allow_nil: true
    }
  validates :absences_included_annually,
    numericality: {
      greater_than_or_equal_to: 0,
      only_integer: true
    }

  after_save :reset_cache!
  after_commit :update_baskets_async, on: :update

  def self.create_default!
    create!(names: ACP.languages.map { |l|
      [ l, I18n.t("delivery_cycle.default_name", locale: l) ]
    }.to_h)
  end

  def self.for(delivery)
    DeliveryCycle.all.select { |dc| dc.include_delivery?(delivery) }
  end

  def self.billable_deliveries_counts
    if visible?
      visible.map(&:billable_deliveries_count).uniq.sort
    else
      [ greatest.billable_deliveries_count ]
    end
  end

  def self.billable_deliveries_count_for(basket_complement)
    if visible?
      visible.map { |dc| dc.billable_deliveries_count_for(basket_complement) }.uniq.sort
    else
      [ greatest.billable_deliveries_count_for(basket_complement) ]
    end
  end

  def self.future_deliveries_counts
    if visible?
      visible.map(&:future_deliveries_count).uniq.sort
    else
      [ greatest.future_deliveries_count ]
    end
  end

  def self.basket_size_config?
    BasketSize.visible.where.not(delivery_cycle_id: nil).any?
  end

  def self.visible?
    !basket_size_config? && visible.many?
  end

  def self.greatest
    all.max_by(&:billable_deliveries_count)
  end

  def self.member_ordered
    all.to_a.sort_by { |dc|
      clauses = [ dc.member_order_priority ]
      clauses <<
        case Current.acp.delivery_cycles_member_order_mode
        when "deliveries_count_asc"; dc.billable_deliveries_count
        when "deliveries_count_desc"; -dc.billable_deliveries_count
        when "wdays_asc"; [ dc.wdays.sort, -dc.billable_deliveries_count ]
        end
      clauses << dc.public_name
      clauses
    }
  end

  def self.reset_cache!
    find_each(&:reset_cache!)
  end

  def reset_cache!
    min = Current.acp.fiscal_year_for(Delivery.minimum(:date))&.year || Current.fy_year
    max = Current.acp.next_fiscal_year.year
    counts = (min..max).map { |y| [ y.to_s, deliveries(y).count ] }.to_h

    update_column(:deliveries_counts, counts)
  end

  def display_name; name end

  def public_name
    self[:public_names][I18n.locale.to_s].presence || name
  end

  def visible?
    depots.visible.any?
  end

  def next_delivery
    (current_deliveries + future_deliveries).select { |d| d.date >= Date.current }.min_by(&:date)
  end

  def deliveries_count
    future_deliveries_count.positive? ? future_deliveries_count : current_deliveries_count
  end

  def billable_deliveries_count
    deliveries_count - absences_included_annually
  end

  # Pro-rate included absences removal
  def billable_deliveries_count_for(basket_complement)
    count = (basket_complement.delivery_ids & current_and_future_delivery_ids).size
    if absences_included_annually.positive?
      full_year = deliveries_count.to_f
      count -= (count / full_year * absences_included_annually).round
    end
    count
  end

  def current_deliveries_count
    deliveries_count_for Current.fy_year
  end

  def future_deliveries_count
    deliveries_count_for Current.fy_year + 1
  end

  def deliveries_count_for(year)
    deliveries_counts[year.to_s].to_i
  end

  def include_delivery?(delivery)
    deliveries(delivery.date).include?(delivery)
  end

  def deliveries_in(range)
    deliveries(range.min).select { |d| range.cover?(d.date) }
  end

  def current_deliveries
    @current_deliveries ||= deliveries(Current.fy_year)
  end

  def future_deliveries
    @future_deliveries ||= deliveries(Current.fy_year + 1)
  end

  def current_and_future_delivery_ids
    (current_deliveries + future_deliveries).map(&:id).uniq
  end

  def coming_deliveries
    (current_deliveries + future_deliveries).select { |d|
      d.date >= Date.current
    }.uniq
  end

  def wdays=(wdays)
    super wdays.map(&:to_s) & Array(0..6).map(&:to_s)
  end

  def months=(months)
    super months.map(&:to_s) & Array(1..12).map(&:to_s)
  end

  def can_destroy?
    memberships.none? &&
      memberships_basket_complements.none? &&
      basket_sizes.none? &&
      DeliveryCycle.where.not(id: id).exists?
  end

  def deliveries(year)
    scoped =
      Delivery
        .where("EXTRACT(DOW FROM date) IN (?)", wdays)
        .where("EXTRACT(MONTH FROM date) IN (?)", months)
        .during_year(year)
    if odd_week_numbers?
      scoped = scoped.where("EXTRACT(WEEK FROM date)::integer % 2 = ?", 1)
    elsif even_week_numbers?
      scoped = scoped.where("EXTRACT(WEEK FROM date)::integer % 2 = ?", 0)
    end
    if all_but_first_results?
      scoped = scoped.to_a[1..-1] || []
    elsif odd_results?
      scoped = scoped.to_a.select.with_index { |_, i| (i + 1).odd? }
    elsif even_results?
      scoped = scoped.to_a.select.with_index { |_, i| (i + 1).even? }
    elsif quarter_1_results?
      scoped = scoped.to_a.select.with_index { |_, i| i % 4 == 0 }
    elsif quarter_2_results?
      scoped = scoped.to_a.select.with_index { |_, i| i % 4 == 1 }
    elsif quarter_3_results?
      scoped = scoped.to_a.select.with_index { |_, i| i % 4 == 2 }
    elsif quarter_4_results?
      scoped = scoped.to_a.select.with_index { |_, i| i % 4 == 3 }
    elsif first_of_each_month_results?
      scoped = scoped.to_a.group_by { |d| d.date.mon }.map { |_, ds| ds.first }
    elsif last_of_each_month_results?
      scoped = scoped.to_a.group_by { |d| d.date.mon }.map { |_, ds| ds.last }
    end
    if minimum_gap_in_days.present?
      scoped = enforce_minimum_gap_in_days(scoped.to_a)
    end
    scoped
  end

  private

  def update_baskets_async
    if (CONFIGURATION_ATTRIBUTES & saved_changes.keys).any?
      DeliveryCycleBasketsUpdaterJob.perform_later(self)
    end
  end

  def enforce_minimum_gap_in_days(deliveries)
    past_date = nil
    deliveries.select { |d|
      if past_date.nil? || (d.date - past_date) >= minimum_gap_in_days
        past_date = d.date
        true
      end
    }
  end
end
