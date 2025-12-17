# frozen_string_literal: true

class DeliveryCycle < ApplicationRecord
  MEMBER_ORDER_MODES = %w[
    name_asc
    deliveries_count_asc
    deliveries_count_desc
    wdays_asc
  ]
  CONFIGURATION_ATTRIBUTES = %w[
    wdays
    first_cweek
    last_cweek
    exclude_cweek_range
    week_numbers
  ]

  include TranslatedAttributes
  include HasPublicName
  include Discardable
  include HasPrice

  enum :week_numbers, %i[all odd even], suffix: true

  has_many :memberships
  has_many :periods,
    -> { order(:from_fy_month, :to_fy_month) },
    class_name: "DeliveryCycle::Period",
    dependent: :destroy
  has_many :memberships_basket_complements
  has_many :basket_sizes, -> { kept }

  has_and_belongs_to_many :depots, -> { kept } # Visibility

  translated_attributes :invoice_name
  translated_attributes :form_detail

  accepts_nested_attributes_for :periods, allow_destroy: true

  scope :ordered, -> { order_by_name }
  scope :visible, -> {
    unscoped.kept.joins(:depots).merge(Depot.unscoped.visible).distinct
  }

  validates :absences_included_annually,
    presence: true,
    numericality: {
      greater_than_or_equal_to: 0,
      only_integer: true
    }
  validates :first_cweek, :last_cweek,
    numericality: {
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 53,
      only_integer: true,
      allow_nil: true
    }
  validate :must_have_at_least_one_period

  before_save :track_periods_changes
  after_save :reset_cache!, if: :configuration_or_periods_changed?
  after_commit :update_baskets_async, on: :update, if: :configuration_or_periods_changed?

  def self.create_default!
    create!(
      names: Organization.languages.map { |l|
        [ l, I18n.t("delivery_cycle.default_name", locale: l) ]
      }.to_h,
      periods_attributes: [ { from_fy_month: 1, to_fy_month: 12 } ])
  end

  def self.for(delivery)
    DeliveryCycle.kept.select { |dc| dc.include_delivery?(delivery) }
  end

  def self.billable_deliveries_counts
    if visible?
      visible.map(&:billable_deliveries_count).uniq.sort
    else
      [ primary.billable_deliveries_count ]
    end
  end

  def self.billable_deliveries_count_for(basket_complement)
    if visible?
      visible.map { |dc| dc.billable_deliveries_count_for(basket_complement) }.uniq.sort
    else
      [ primary.billable_deliveries_count_for(basket_complement) ]
    end
  end

  def self.future_deliveries_counts
    if visible?
      visible.map(&:future_deliveries_count).uniq.sort
    else
      [ primary.future_deliveries_count ]
    end
  end

  def self.basket_size_config?
    BasketSize.visible.where.not(delivery_cycle_id: nil).any?
  end

  def self.visible?
    !basket_size_config? && visible.many?
  end

  def self.prices?
    kept.pluck(:price).any?(&:positive?)
  end

  # Prioritize visible delivery cycles over non-visible ones, even if a
  # non-visible cycle has more billable deliveries.
  def self.primary
    visible.max_by(&:billable_deliveries_count) || kept.max_by(&:billable_deliveries_count)
  end

  def self.member_ordered
    kept.to_a.sort_by { |dc|
      clauses = [ dc.member_order_priority ]
      clauses <<
        case Current.org.delivery_cycles_member_order_mode
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
    min = Current.org.fiscal_year_for(Delivery.minimum(:date))&.year || Current.fy_year
    max = Current.org.next_fiscal_year.year
    counts = (min..max).map { |y| [ y.to_s, deliveries(y).count ] }.to_h

    update_column(:deliveries_counts, counts)
  end

  def primary?
    self == self.class.primary
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
      if full_year.positive?
        count -= (count / full_year * absences_included_annually).round
      end
    end
    count
  end

  def invoice_description
    if invoice_name?
      invoice_name
    else
      [ Delivery.model_name.human(count: 2), public_name ].join(": ")
    end
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
    super wdays.map(&:presence).compact.map(&:to_i) & Array(0..6).map(&:to_i)
  end

  def can_delete?
    memberships.none? &&
      memberships_basket_complements.none? &&
      basket_sizes.none? &&
      DeliveryCycle.where.not(id: id).exists?
  end

  def can_discard?
    memberships.current_and_future_year.none? &&
      memberships_basket_complements.current_and_future_year.none? &&
      basket_sizes.none? &&
      DeliveryCycle.where.not(id: id).exists?
  end

  def deliveries(year)
    fiscal_year = Current.org.fiscal_year_for(year)
    first_cweek_year = fiscal_year.beginning_of_year.year
    last_cweek_year = fiscal_year.end_of_year.year

    scoped =
      Delivery
        .where("time_get_weekday(time_parse(date)) IN (?)", wdays)
        .during_year(year)

    if first_cweek.present? && last_cweek.present?
      if exclude_cweek_range?
        # Exclude deliveries inside the range (keep deliveries outside)
        scoped = scoped.where(
          "(time_get_isoyear(time_parse(date)) < :first_year OR time_get_isoweek(time_parse(date)) < :first_cweek) OR " \
          "(time_get_isoyear(time_parse(date)) > :last_year OR time_get_isoweek(time_parse(date)) > :last_cweek)",
          first_year: first_cweek_year,
          first_cweek: first_cweek,
          last_year: last_cweek_year,
          last_cweek: last_cweek
        )
      else
        # Include deliveries inside the range (exclude deliveries outside)
        scoped = scoped.where(
          "time_get_isoyear(time_parse(date)) > :year OR time_get_isoweek(time_parse(date)) >= :cweek",
          year: first_cweek_year,
          cweek: first_cweek
        )
        scoped = scoped.where(
          "time_get_isoyear(time_parse(date)) < :year OR time_get_isoweek(time_parse(date)) <= :cweek",
          year: last_cweek_year,
          cweek: last_cweek
        )
      end
    elsif first_cweek.present?
      scoped = scoped.where(
        "time_get_isoyear(time_parse(date)) > :year OR time_get_isoweek(time_parse(date)) >= :cweek",
        year: first_cweek_year,
        cweek: first_cweek
      )
    elsif last_cweek.present?
      scoped = scoped.where(
        "time_get_isoyear(time_parse(date)) < :year OR time_get_isoweek(time_parse(date)) <= :cweek",
        year: last_cweek_year,
        cweek: last_cweek
      )
    end
    if odd_week_numbers?
      scoped = scoped.where("time_get_isoweek(time_parse(date)) % 2 = ?", 1)
    elsif even_week_numbers?
      scoped = scoped.where("time_get_isoweek(time_parse(date)) % 2 = ?", 0)
    end

    base_deliveries = scoped.to_a

    deliveries = periods.flat_map { |p| p.filter(base_deliveries) }
    deliveries.uniq.sort_by(&:date)
  end

  private

  def must_have_at_least_one_period
    return if periods.reject(&:marked_for_destruction?).any?

    errors.add(:periods, :blank)
  end

  def update_baskets_async
    DeliveryCycleBasketsUpdaterJob.perform_later(self)
  end

  def track_periods_changes
    @periods_changed =
      periods.any? { |p|
        p.new_record? || p.marked_for_destruction? || p.has_changes_to_save?
      }
  end

  def configuration_or_periods_changed?
    config_changed = (CONFIGURATION_ATTRIBUTES & saved_changes.keys).any?
    config_changed || @periods_changed
  end
end
