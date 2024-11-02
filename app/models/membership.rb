# frozen_string_literal: true

require "rounding"

class Membership < ApplicationRecord
  include HasDescription

  attr_accessor :renewal_decision

  RENEWAL_STATES = %w[
    renewal_pending
    renewal_opened
    renewal_canceled
    renewed
  ].freeze

  attribute :new_config_from, :date

  belongs_to :member, counter_cache: true
  belongs_to :basket_size
  belongs_to :depot
  belongs_to :delivery_cycle
  has_many :baskets, dependent: :destroy
  has_one :next_basket, -> { merge(Basket.deliverable.coming) }, class_name: "Basket"
  has_many :basket_sizes, -> { reorder_by_name }, through: :baskets
  has_many :depots, -> { distinct.reorder(:position) }, through: :baskets
  has_many :deliveries, through: :baskets
  has_many :basket_complements, -> { reorder_by_name }, source: :complements, through: :baskets
  has_many :memberships_basket_complements, dependent: :destroy, validate: true
  has_many :subscribed_basket_complements,
    source: :basket_complement,
    through: :memberships_basket_complements
  has_many :invoices, as: :entity

  accepts_nested_attributes_for :memberships_basket_complements, allow_destroy: true

  after_initialize do
    unless new_record?
      self.new_config_from ||= [ [ Date.today, started_on ].max, ended_on ].min
    end
  end
  before_validation do
    self.basket_price ||= basket_size&.price
    self.depot_price ||= depot&.price
    self.activity_participations_demanded_annually ||= activity_participations_demanded_annually_by_default
    self.absences_included_annually ||= delivery_cycle&.absences_included_annually
  end

  validates :member, presence: true
  validates :delivery_cycle, presence: true
  validates :activity_participations_demanded_annually, numericality: true
  validates :activity_participations_annual_price_change, numericality: true, allow_nil: true
  validates :started_on, :ended_on, presence: true
  validates :basket_quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :basket_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :depot_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :basket_price_extra, numericality: true, presence: true
  validates :baskets_annual_price_change, numericality: true
  validates :basket_complements_annual_price_change, numericality: true
  validates :absences_included_annually, numericality: true
  validates :billing_year_division, presence: true, inclusion: { in: Organization.billing_year_divisions }
  validates :new_config_from,
    date: {
      after_or_equal_to: :started_on,
      before_or_equal_to: :ended_on
    },
    on: :update
  validate :good_period_range
  validate :cannot_update_dates_when_renewed
  validate :only_one_per_year
  validate :unique_subscribed_basket_complement_id
  validate :at_least_one_basket
  before_save :set_renew
  before_save :set_activity_participations
  after_create :create_baskets!
  after_create :clear_member_waiting_info!
  after_update :handle_started_on_change!
  after_update :handle_ended_on_change!
  after_update :handle_config_change!
  after_update :keep_renewed_membership_up_to_date!
  after_destroy :update_renewal_of_previous_membership_after_deletion, :destroy_or_cancel_invoices!
  after_commit :update_renewal_of_previous_membership_after_creation, on: :create
  after_commit :update_absences_included!, on: %i[create update]
  after_commit :update_member_and_baskets!
  after_commit :update_price_and_invoices_amount!, on: %i[create update]

  scope :started, -> { where(started_on: ..Date.yesterday) }
  scope :past, -> { where(ended_on: ..Date.yesterday) }
  scope :future, -> { where(started_on: Date.tomorrow..) }
  scope :trial, -> { current.where(remaning_trial_baskets_count: 1..) }
  scope :ongoing, -> { current.where(remaning_trial_baskets_count: 0) }
  scope :current, -> { including_date(Date.current) }
  scope :current_or_future, -> { current.or(future).order(:started_on) }
  scope :including_date, ->(date) { where(started_on: ..date, ended_on: date..) }
  scope :duration_gt, ->(days) { where("julianday(ended_on) - julianday(started_on) > ?", days) }
  scope :current_year, -> { during_year(Current.fy_year) }
  scope :during_year, ->(year) {
    fy = Current.org.fiscal_year_for(year)
    where(started_on: fy.range.min.., ended_on: ..fy.range.max)
  }
  scope :current_and_future_year, -> { where(started_on: Current.fy_range.min..) }
  scope :overlaps, ->(period) { where(started_on: ..period.max, ended_on: period.min..) }
  scope :renewed, -> { where.not(renewed_at: nil) }
  scope :not_renewed, -> { where(renewed_at: nil) }
  scope :renewal_state_eq, ->(state) {
    case state.to_sym
    when :renewal_pending
      not_renewed.where(renew: true, renewal_opened_at: nil)
    when :renewal_opened
      not_renewed.where(renew: true).where.not(renewal_opened_at: nil)
    when :renewal_canceled
      where(renew: false)
    when :renewed
      renewed
    end
  }
  scope :with_memberships_basket_complement, ->(id) {
    left_joins(:memberships_basket_complements)
      .where(memberships_basket_complements: { basket_complement_id: id })
  }
  scope :activity_participations_missing_eq, ->(count) {
    where("MAX(activity_participations_demanded - activity_participations_accepted, 0) = ?", count)
  }
  scope :activity_participations_missing_gt, ->(count) {
    where("MAX(activity_participations_demanded - activity_participations_accepted, 0) > ?", count)
  }
  scope :activity_participations_missing_lt, ->(count) {
    where("MAX(activity_participations_demanded - activity_participations_accepted, 0) < ?", count)
  }

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[
      during_year
      renewal_state_eq
      with_memberships_basket_complement
      activity_participations_missing_eq
      activity_participations_missing_gt
      activity_participations_missing_lt
    ]
  end

  def self.human_attribute_name(attr, *args)
    if attr == :basket_price_extra_title
      Current.org.basket_price_extra_title
    else
      super
    end
  end

  def self.used_delivery_cycle_ids_for(year)
    during_year(year).distinct.pluck(:delivery_cycle_id)
  end

  def basket_description(public_name: false)
    describe(basket_size, basket_quantity, public_name: public_name)
  end

  def billable?
    fy_year >= Current.fy_year &&
      (missing_invoices_amount.positive? || overcharged_invoices_amount?)
  end

  def first_billable_delivery
    rel = baskets.filled.billable
    (rel.trial.last || rel.first)&.delivery
  end

  def trial?
    remaning_trial_baskets_count.positive?
  end

  def trial_only?
    baskets_count == trial_baskets_count
  end

  def fiscal_year
    @fiscal_year ||= Current.org.fiscal_year_for(started_on)
  end

  def fy_year
    fiscal_year.year
  end

  def future?
    started_on > Date.current
  end

  def started?
    started_on <= Date.current
  end

  def past?
    ended_on < Date.current
  end

  def current?
    started? && ended_on >= Date.current
  end

  def current_or_future_year?
    fy_year >= Current.fy_year
  end

  def can_destroy?
    current_or_future_year?
  end

  def can_update?
    current_or_future_year?
  end

  def can_send_email?
    member.emails?
  end

  def can_member_update?
    return false unless Current.org.membership_depot_update_allowed?

    member_updatable_baskets.any?
  end

  def can_clear_activity_participations_demanded?
    return false unless Current.org.feature?("activity")

    fiscal_year.past? && activity_participations_demanded > activity_participations_accepted
  end

  def member_updatable_baskets
    baskets.includes(:delivery).select(&:can_member_update?)
  end

  def member_update!(params)
    raise "update not allowed" unless can_member_update?
    return unless params.key?(:depot_id)

    depot = Depot.find(params[:depot_id])
    params[:depot_price] = depot.price
    params = params.to_h.slice(:depot_id, :depot_price)

    transaction do
      update_columns(params)
      member_updatable_baskets.each { |b| b.update!(params) }
    end
  end

  def state
    if current?
      trial? ? "trial" : "ongoing"
    elsif future?
      "future"
    else
      "past"
    end
  end

  def renewal_state
    if renewed?
      :renewed
    elsif canceled?
      :renewal_canceled
    elsif renewal_opened?
      :renewal_opened
    else
      :renewal_pending
    end
  end

  def mark_renewal_as_pending!
    raise "cannot mark renewal as pending on an already renewed membership" if renewed?
    raise "renewal already pending" if renew?

    self[:renew] = true
    save!
  end

  def open_renewal!
    unless MailTemplate.active_template(:membership_renewal)
      raise "membership_renewal mail template not active"
    end
    raise "already renewed" if renewed?
    raise "`renew` must be true before opening renewal" unless renew?
    unless Delivery.any_next_year?
      raise MembershipRenewal::MissingDeliveriesError, "Deliveries for next fiscal year are missing."
    end
    return unless can_send_email?

    MailTemplate.deliver_later(:membership_renewal,
      membership: self)
    touch(:renewal_opened_at)
  end

  def renewal_pending?
    renew? && !renewed? && !renewal_opened_at?
  end

  def renewal_opened?
    renew? && !renewed? && renewal_opened_at?
  end

  def renew!(attrs = {})
    return if renewed?
    raise "`renew` must be true for renewing" unless renew?

    renewal = MembershipRenewal.new(self)
    transaction do
      renewal.renew!(attrs)
      self[:renewal_note] = attrs[:renewal_note]
      self[:renewed_at] = Time.current
      save!
    end
  end

  def renewed?
    renewed_at?
  end

  def can_renew?
    delivery_cycle&.future_deliveries&.any?
  end

  def renewed_membership
    return unless renewed?

    @renewed_membership ||= member.memberships.during_year(fy_year + 1).first
  end

  def previous_membership
    @previous_membership ||= member.memberships.during_year(fy_year - 1).first
  end

  def cancel!(attrs = {})
    return if canceled?
    raise "cannot cancel an already renewed membership" if renewed?

    if Current.org.annual_fee?
      if ActiveRecord::Type::Boolean.new.cast(attrs[:renewal_annual_fee])
        self[:renewal_annual_fee] = Current.org.annual_fee
      end
    end
    self[:renewal_note] = attrs[:renewal_note]
    self[:renewal_opened_at] = nil
    self[:renewed_at] = nil
    self[:renew] = false
    save!
  end

  def canceled?
    persisted? && !renew?
  end

  def memberships_basket_complements_attributes=(*args)
    @tracked_memberships_basket_complements_attributes =
      memberships_basket_complements.map(&:attributes)
    super
  end

  def baskets_annual_price_change=(price)
    super rounded_price(price.to_f)
  end

  def basket_complements_annual_price_change=(price)
    super rounded_price(price.to_f)
  end

  def activity_participations_annual_price_change=(price)
    super price.presence && rounded_price(price.to_f)
  end

  def activity_participations_demanded_annually_by_default
    return 0 unless Current.org.feature?("activity")

    count = basket_quantity * basket_size&.activity_participations_demanded_annually
    memberships_basket_complements.each do |mbc|
      count += mbc.quantity * mbc.basket_complement&.activity_participations_demanded_annually.to_i
    end
    count
  end

  def activity_participations_demanded_diff_from_default
    copy = dup
    copy.activity_participations_demanded_annually = activity_participations_demanded_annually_by_default
    activity_participations_demanded - ActivityParticipationDemanded.new(copy).count
  end

  def basket_sizes_price
    rounded_price(
      baskets
        .billable
        .sum("quantity * basket_price"))
  end

  def basket_size_price(basket_size_id)
    rounded_price(
      baskets
        .billable
        .where(basket_size_id: basket_size_id)
        .sum("quantity * basket_price"))
  end

  def baskets_price_extra
    rounded_price(
      baskets
        .billable
        .sum("quantity * calculated_price_extra"))
  end

  def basket_complements_price
    ids = baskets.joins(:baskets_basket_complements).pluck(:basket_complement_id).uniq
    BasketComplement.find(ids).sum { |bc| basket_complement_total_price(bc) }
  end

  def basket_complement_total_price(basket_complement)
    rounded_price(
      baskets
        .billable
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { basket_complement: basket_complement })
        .sum("baskets_basket_complements.quantity * baskets_basket_complements.price"))
  end

  def depots_price
    baskets.pluck(:depot_id).uniq.sum { |id| depot_total_price(id) }
  end

  def depot_total_price(depot_id)
    rounded_price(
      baskets
        .billable
        .where(depot_id: depot_id)
        .sum("quantity * depot_price"))
  end

  def missing_invoices_amount
    [ price - invoices_amount, 0 ].max
  end

  def first_delivery
    baskets.first&.delivery
  end

  def period
    started_on..ended_on
  end

  def display_period
    [ started_on, ended_on ].map { |date|
      format = Current.org.fiscal_year_start_month == 1 ? :short_no_year : :short
      I18n.l(date, format: format)
    }.join(" – ")
  end

  def basket_size
    return unless basket_size_id

    @basket_size ||= BasketSize.find(basket_size_id)
  end

  def depot
    return unless depot_id

    @depot ||= Depot.find(depot_id)
  end

  def activity_participations_missing
    return 0 if trial? || trial_only?

    [ activity_participations_demanded - activity_participations_accepted, 0 ].max
  end

  def update_activity_participations_accepted!
    participations = member.activity_participations.not_rejected.during_year(fiscal_year)
    invoices = member.invoices.not_canceled.activity_participations_fiscal_year(fiscal_year)
    update_column(
      :activity_participations_accepted,
      participations.sum(:participants_count) + invoices.sum(:missing_activity_participations_count))
  end

  def clear_activity_participations_demanded!
    return unless Current.org.feature?("activity")

    update_column(:activity_participations_demanded, 0)
  end

  def update_baskets_counts!
    return if destroyed?

    cols = { past_baskets_count: baskets.past.count }
    if Current.org.trial_baskets_count.positive?
      cols[:remaning_trial_baskets_count] = baskets.coming.trial.count
      cols[:trial_baskets_count] = baskets.trial.count
    end
    update_columns(cols)
  end

  def create_basket!(delivery)
    baskets.create!(
      delivery_id: delivery.id,
      basket_size_id: basket_size_id,
      basket_price: basket_price,
      price_extra: basket_price_extra,
      quantity: basket_quantity,
      depot_id: depot_id,
      depot_price: depot_price)
  end

  def overcharged_invoices_amount?
    invoices.not_canceled.any? && invoices_amount > price
  end

  def cancel_overcharged_invoice!
    return if destroyed?
    return unless current_or_future_year?
    return unless overcharged_invoices_amount?

    invoices.not_canceled.order(:id).last.destroy_or_cancel!
    update_price_and_invoices_amount!
    cancel_overcharged_invoice!
  end

  private

  def set_renew
    if ended_on_changed?
      self.renew = (ended_on >= Current.fy_range.max)
    end
  end

  def set_activity_participations
    if Current.org.feature?("activity")
      self.activity_participations_demanded = ActivityParticipationDemanded.new(self).count
      self.activity_participations_annual_price_change ||=
        -1 * activity_participations_demanded_diff_from_default * Current.org.activity_price
    else
      self.activity_participations_demanded = 0
      self.activity_participations_annual_price_change = 0
    end
  end

  def handle_started_on_change!
    if saved_change_to_attribute?(:started_on) && attribute_before_last_save(:started_on)
      destroy_baskets!(fiscal_year.range.min...started_on)
      if attribute_before_last_save(:started_on) > started_on
        create_baskets!(started_on...attribute_before_last_save(:started_on))
      end
    end
  end

  def handle_ended_on_change!
    if saved_change_to_attribute?(:ended_on) && attribute_before_last_save(:ended_on)
      destroy_baskets!((ended_on + 1.day)..fiscal_year.range.max)
      if attribute_before_last_save(:ended_on) < ended_on
        create_baskets!((attribute_before_last_save(:ended_on) + 1.day)..ended_on)
      end
    end
  end

  def handle_config_change!
    return unless attributes_config_changed? || memberships_basket_complements_config_changed?

    range = new_config_from..ended_on
    destroy_baskets!(range)
    create_baskets!(range)
  end

  def keep_renewed_membership_up_to_date!
    return unless renewed_membership
    return unless saved_change_to_attribute?(:billing_year_division)

    renewed_membership.update_column(:billing_year_division, billing_year_division)
  end

  def attributes_config_changed?
    tracked_attributes = %w[
      basket_size_id basket_price basket_price_extra basket_quantity
      depot_id depot_price delivery_cycle_id
    ]
    (saved_changes.keys & tracked_attributes).any? || !new_config_from.today?
  end

  def memberships_basket_complements_config_changed?
    @tracked_memberships_basket_complements_attributes &&
      @tracked_memberships_basket_complements_attributes !=
        memberships_basket_complements.map(&:attributes)
  end

  def create_baskets!(range = period)
    delivery_cycle.deliveries_in(range).each do |delivery|
      create_basket!(delivery)
    end
  end

  def destroy_baskets!(range)
    baskets.between(range).destroy_all
  end

  def clear_member_waiting_info!
    member.update!(
      waiting_started_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      waiting_delivery_cycle: nil,
      waiting_basket_complement_ids: nil)
  end

  def update_absences_included!
    return unless Current.org.feature?("absence")

    full_year = delivery_cycle.deliveries_in(fiscal_year.range).size.to_f
    total = (baskets.count / full_year * absences_included_annually).round
    unless total == absences_included
      update_column(:absences_included, total)
    end
  end

  def update_member_and_baskets!
    update_absent_baskets!
    update_not_billable_baskets!
    member.reload
    member.update_trial_baskets!
    update_baskets_counts!
    member.review_active_state!
  end

  def update_absent_baskets!
    return unless Current.org.feature?("absence")
    return if destroyed?

    transaction do
      # Real absences
      baskets.absent.update_all(state: "normal", absence_id: nil)
      member.absences.overlaps(period).each do |absence|
        baskets
          .between(absence.period)
          .update_all(state: "absent", absence_id: absence.id)
      end
      # Provisional absences (included)
      remaining = absences_included - baskets.absent.count
      if remaining.positive?
        baskets
          .not_absent
          .reorder("deliveries.date DESC")
          .limit(remaining)
          .update_all(state: "absent")
      end
    end
  end

  def update_not_billable_baskets!
    return unless Current.org.feature?("absence")
    return if destroyed?

    transaction do
      baskets.not_billable.update_all(billable: true)
      absent_baskets = baskets.absent
      if Current.org.absences_billed?
        absent_baskets = absent_baskets.limit(absences_included)
      end
      absent_baskets.update_all(billable: false)
    end
  end

  def update_price_and_invoices_amount!
    update_columns(
      price: (basket_sizes_price +
        baskets_price_extra +
        baskets_annual_price_change +
        basket_complements_price +
        basket_complements_annual_price_change +
        depots_price +
        activity_participations_annual_price_change),
      invoices_amount: invoices.not_canceled.sum(:memberships_amount))
  end

  def update_renewal_of_previous_membership_after_creation
    if previous_membership&.renewal_state&.in?(%i[renewal_pending renewal_opened])
      previous_membership.update_columns(
        renewal_opened_at: nil,
        renewed_at: created_at,
        renew: true)
    end
  end

  def update_renewal_of_previous_membership_after_deletion
    case started_on
    when Current.fiscal_year.end_of_year + 1.day
      previous_membership&.update_columns(
        renewal_opened_at: nil,
        renewed_at: nil,
        renew: true)
    when Current.fiscal_year.beginning_of_year
      previous_membership&.update_columns(
        renewal_opened_at: nil,
        renewed_at: nil,
        renew: false)
    end
  end

  def destroy_or_cancel_invoices!
    invoices.not_canceled.order(id: :desc).each(&:destroy_or_cancel!)
  end

  def only_one_per_year
    return unless member

    if member.memberships.during_year(fy_year).where.not(id: id).exists?
      errors.add(:member, :taken)
    end
  end

  def at_least_one_basket
    if period && period.min && delivery_cycle&.deliveries_in(period)&.none?
      errors.add(:started_on, :invalid)
      errors.add(:ended_on, :invalid)
    end
  end

  def good_period_range
    if started_on && ended_on && started_on >= ended_on
      errors.add(:started_on, :before_end)
      errors.add(:ended_on, :after_start)
    end
    if ended_on && fy_year != Current.org.fiscal_year_for(ended_on).year
      errors.add(:started_on, :same_fiscal_year)
      errors.add(:ended_on, :same_fiscal_year)
    end
  end

  def cannot_update_dates_when_renewed
    if renewed? && started_on_changed?
      errors.add(:started_on, :renewed)
    end
    if renewed? && ended_on_changed?
      errors.add(:ended_on, :renewed)
    end
  end

  def unique_subscribed_basket_complement_id
    used_basket_complement_ids = []
    memberships_basket_complements.each do |mbc|
      if mbc.basket_complement_id.in?(used_basket_complement_ids)
        mbc.errors.add(:basket_complement_id, :taken)
        errors.add(:base, :invalid)
      end
      used_basket_complement_ids << mbc.basket_complement_id
    end
  end

  def rounded_price(price)
    return 0 if member.salary_basket?

    price.round_to_five_cents
  end
end
