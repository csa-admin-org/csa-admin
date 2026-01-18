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

  # Sub-model concerns (order matters for callbacks!)
  include Deliveries         # Core delivery querying and counting
  include BillableDeliveries # Billing calculations (depends on Deliveries)
  include Visibility         # Visibility and ordering (depends on BillableDeliveries)
  include Auditing           # Must come after all other concerns

  enum :week_numbers, %i[all odd even], suffix: true

  has_many :memberships
  has_many :periods,
    -> { order(:from_fy_month, :to_fy_month) },
    class_name: "DeliveryCycle::Period",
    dependent: :destroy
  has_many :memberships_basket_complements

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
  after_commit :update_baskets_async, on: :update, if: :configuration_or_periods_changed?

  def self.create_default!
    create!(
      names: Organization.languages.map { |l|
        [ l, I18n.t("delivery_cycle.default_name", locale: l) ]
      }.to_h,
      periods_attributes: [ { from_fy_month: 1, to_fy_month: 12 } ])
  end

  def self.prices?
    kept.pluck(:price).any?(&:positive?)
  end

  def current_year_memberships?
    memberships.current_year.exists?
  end

  def invoice_description
    if invoice_name?
      invoice_name
    else
      [ Delivery.model_name.human(count: 2), public_name ].join(": ")
    end
  end

  def wdays=(wdays)
    super wdays.map(&:presence).compact.map(&:to_i) & Array(0..6).map(&:to_i)
  end

  def can_delete?
    memberships.none?
      && memberships_basket_complements.none?
      && DeliveryCycle.where.not(id: id).exists?
  end

  def can_discard?
    memberships.current_and_future_year.none?
      && memberships_basket_complements.current_and_future_year.none?
      && DeliveryCycle.where.not(id: id).exists?
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
