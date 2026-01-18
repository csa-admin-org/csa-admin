# frozen_string_literal: true

require "rounding"

class Membership < ApplicationRecord
  include HasDescription
  include Timeframe, Absence, AbsencesIncludedRemindable,
          Trial, Renewal, Pricing, Activity
  include Auditing # Must come after all other concerns

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
  has_many :forced_deliveries, dependent: :destroy
  has_many :bidding_round_pledges,
    class_name: "BiddingRound::Pledge",
    dependent: :destroy

  accepts_nested_attributes_for :memberships_basket_complements, allow_destroy: true

  after_initialize do
    unless new_record?
      self.new_config_from ||= [ [ Date.current, started_on ].max, ended_on ].min
    end
  end
  before_validation do
    # Keep new_config_from within the membership period range
    self.new_config_from = [ [ new_config_from || Date.current, started_on ].max, ended_on ].min
    @default_basket_size_price_used = basket_size_price.blank?
    self.basket_size_price ||= basket_size&.price
    self.depot_price ||= depot&.price
    self.delivery_cycle_price ||= delivery_cycle&.price
  end

  validates :member, presence: true
  validates :delivery_cycle, presence: true
  validates :basket_quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :basket_size_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :depot_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :delivery_cycle_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :basket_price_extra, numericality: true, presence: true
  validates :baskets_annual_price_change, numericality: true
  validates :basket_complements_annual_price_change, numericality: true
  validates :billing_year_division, presence: true, inclusion: { in: Organization.billing_year_divisions }
  validate :cannot_update_dates_when_renewed
  validate :only_one_per_year
  validate :unique_subscribed_basket_complement_id
  validate :at_least_one_basket

  # Lifecycle callbacks - grouped by purpose
  after_create :setup_new_membership!
  after_update :sync_baskets_after_update!
  after_destroy :cleanup_on_destroy!

  # after_commit runs after transaction commits - order matters:
  # 1. Link to previous membership's renewal state (on create only)
  # 2. Sync member and basket states (absences, trial, counts)
  # 3. Recalculate price based on final basket state
  after_commit :finalize_after_create!, on: :create
  after_commit :finalize_after_save!, on: %i[create update]
  after_touch :update_member_and_baskets!

  scope :with_memberships_basket_complement, ->(id) {
    left_joins(:memberships_basket_complements)
      .where(memberships_basket_complements: { basket_complement_id: id })
  }

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[
      renewal_state_eq
      with_memberships_basket_complement
      activity_participations_missing_eq
      activity_participations_missing_gt
      activity_participations_missing_lt
    ]
  end

  ACTIVITY_SCOPED_ATTRIBUTES = %w[
    activity_participations_demanded_annually
    activity_participations_annual_price_change
  ].freeze

  def self.human_attribute_name(attr, *args)
    attr = attr.to_s
    if attr == "basket_price_extra_title"
      Current.org.basket_price_extra_title
    elsif attr.in?(ACTIVITY_SCOPED_ATTRIBUTES)
      super("#{attr}/#{Current.org.activity_i18n_scope}", *args)
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

  def memberships_basket_complements_attributes=(*args)
    @tracked_memberships_basket_complements_attributes =
      memberships_basket_complements.map(&:attributes)
    super
  end

  def first_delivery
    baskets.first&.delivery
  end

  def last_delivery
    baskets.last&.delivery
  end

  def basket_size
    return unless basket_size_id

    @basket_size ||= BasketSize.find(basket_size_id)
  end

  def depot
    return unless depot_id

    @depot ||= Depot.find(depot_id)
  end

  def update_baskets_counts!
    return if destroyed?

    update_columns(
      baskets_count: baskets.countable.count,
      past_baskets_count: baskets.countable.past.count,
      remaining_trial_baskets_count: baskets.coming.trial.count,
      trial_baskets_count: baskets.trial.count)
  end

  def create_basket!(delivery)
    baskets.create!(
      delivery_id: delivery.id,
      delivery_cycle_price: delivery_cycle_price,
      basket_size_id: basket_size_id,
      basket_size_price: @default_basket_size_price_used ? nil : basket_size_price,
      price_extra: basket_price_extra,
      quantity: basket_quantity,
      depot_id: depot_id,
      depot_price: depot_price)
  end

  def basket_shift_allowed?
    basket_shifts_allowance_remaining.positive?
  end

  def basket_shifts_allowance_remaining
    return 0 unless Current.org.basket_shift_enabled?
    return Float::INFINITY unless Current.org.basket_shift_annual_limit?

    [ Current.org.basket_shifts_annually - basket_shifts_count, 0 ].max
  end

  def basket_shifts_count
    baskets.joins(:shift_as_source).count
  end

  private

  def setup_new_membership!
    create_baskets!
    clear_member_waiting_info!
  end

  def sync_baskets_after_update!
    sync_baskets_with_started_on_change!
    sync_baskets_with_ended_on_change!
    sync_baskets_with_config_change!
    delete_bidding_round_pledge_on_basket_size_change!
  end

  def cleanup_on_destroy!
    update_renewal_of_previous_membership_after_deletion
    destroy_or_cancel_invoices!
  end

  def finalize_after_create!
    update_renewal_of_previous_membership_after_creation
    update_member_and_baskets!
  end

  def finalize_after_save!
    update_member_and_baskets!
    update_price_and_invoices_amount!
  end

  def sync_baskets_with_started_on_change!
    if saved_change_to_attribute?(:started_on) && attribute_before_last_save(:started_on)
      destroy_baskets!(fiscal_year.range.min...started_on)
      if attribute_before_last_save(:started_on) > started_on
        create_baskets!(started_on...attribute_before_last_save(:started_on))
      end
    end
  end

  def sync_baskets_with_ended_on_change!
    if saved_change_to_attribute?(:ended_on) && attribute_before_last_save(:ended_on)
      destroy_baskets!((ended_on + 1.day)..fiscal_year.range.max)
      if attribute_before_last_save(:ended_on) < ended_on
        create_baskets!((attribute_before_last_save(:ended_on) + 1.day)..ended_on)
      end
    end
  end

  def sync_baskets_with_config_change!
    return unless attributes_config_changed? || memberships_basket_complements_config_changed?

    range = new_config_from..ended_on
    destroy_baskets!(range)
    create_baskets!(range)
  end

  def delete_bidding_round_pledge_on_basket_size_change!
    return unless saved_change_to_attribute?(:basket_size_id)

    bidding_round = BiddingRound.current_open
    return unless bidding_round

    bidding_round.pledges.where(membership_id: id).destroy_all
  end

  def attributes_config_changed?
    tracked_attributes = %w[
      basket_size_id basket_size_price basket_price_extra basket_quantity
      depot_id depot_price delivery_cycle_id delivery_cycle_price
    ]
    (saved_changes.keys & tracked_attributes).any?
      || @default_basket_size_price_used
      || !new_config_from.today?
  end

  def memberships_basket_complements_config_changed?
    @tracked_memberships_basket_complements_attributes
      && @tracked_memberships_basket_complements_attributes !=
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

  def update_member_and_baskets!
    update_absent_baskets!
    update_not_billable_baskets!
    member.reload
    member.update_trial_baskets!
    update_baskets_counts!
    member.review_active_state!
  end

  def only_one_per_year
    return unless member

    if member.memberships.during_year(fy_year).where.not(id: id).exists?
      errors.add(:member, :taken)
    end
  end

  def at_least_one_basket
    if period && period.min && delivery_cycle&.deliveries_in(period)&.none?
      errors.add(:base, :no_deliveries)
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
end
