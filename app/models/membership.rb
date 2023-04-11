require 'rounding'

class Membership < ApplicationRecord
  attr_accessor :renewal_decision

  RENEWAL_STATES = %w[
    renewal_enabled
    renewal_opened
    renewal_canceled
    renewed
  ].freeze

  attribute :new_config_from, :date

  belongs_to :member, counter_cache: true
  belongs_to :basket_size
  belongs_to :depot
  belongs_to :deliveries_cycle
  has_many :baskets, dependent: :destroy
  has_one :next_basket, -> { merge(Basket.not_empty.coming.not_absent) }, class_name: 'Basket'
  has_many :basket_sizes, -> { reorder_by_name }, through: :baskets
  has_many :depots, -> { reorder(:name) }, through: :baskets
  has_many :deliveries, through: :baskets
  has_many :basket_complements, -> { reorder_by_name }, source: :complements, through: :baskets
  has_many :delivered_baskets, -> { delivered }, class_name: 'Basket'
  has_many :memberships_basket_complements, dependent: :destroy, validate: true
  has_many :subscribed_basket_complements,
    source: :basket_complement,
    through: :memberships_basket_complements
  has_many :invoices, as: :object

  accepts_nested_attributes_for :memberships_basket_complements, allow_destroy: true

  after_initialize do
    unless new_record?
      self.new_config_from ||= [[Date.today, started_on].max, ended_on].min
    end
  end
  before_validation do
    self.basket_price ||= basket_size&.price
    self.depot_price ||= depot&.price
    self.activity_participations_demanded_annualy ||= basket_quantity * basket_size&.activity_participations_demanded_annualy
  end

  validates :member, presence: true
  validates :activity_participations_demanded_annualy, numericality: true
  validates :activity_participations_annual_price_change, numericality: true
  validates :started_on, :ended_on, presence: true
  validates :basket_quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :basket_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :depot_price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :basket_price_extra, numericality: true, presence: true
  validates :baskets_annual_price_change, numericality: true
  validates :basket_complements_annual_price_change, numericality: true
  validates :deliveries_cycle, inclusion: { in: ->(m) { m.depot&.deliveries_cycles } }
  validates :new_config_from,
    date: {
      after_or_equal_to: :started_on,
      before_or_equal_to: :ended_on
    },
    on: :update,
    unless: ->(m) { m.started_on_changed? || m.ended_on_changed? }
  validate :good_period_range
  validate :cannot_update_dates_when_renewed
  validate :only_one_per_year
  validate :unique_subscribed_basket_complement_id
  validate :at_least_one_basket

  before_save :set_renew
  after_create :create_baskets!
  after_create :clear_member_waiting_info!
  after_update :handle_started_on_change!
  after_update :handle_ended_on_change!
  after_update :handle_config_change!
  after_update :update_baskets_price_extra!
  after_commit :update_member_and_baskets!, :update_activity_participations_demanded!, :cancel_outdated_invoice!
  after_commit :update_price_and_invoices_amount!, on: %i[create update]
  after_destroy :update_renewal_of_previous_membership, :destroy_or_cancel_invoices!

  scope :started, -> { where('started_on < ?', Time.current) }
  scope :past, -> { where('ended_on < ?', Time.current) }
  scope :future, -> { where('started_on > ?', Time.current) }
  scope :trial, -> { current.where('remaning_trial_baskets_count > 0') }
  scope :ongoing, -> { current.where(remaning_trial_baskets_count: 0) }
  scope :current, -> { including_date(Date.current) }
  scope :current_or_future, -> { current.or(future).order(:started_on) }
  scope :including_date, ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :duration_gt, ->(days) { where("age(ended_on, started_on) > interval '? day'", days) }
  scope :current_year, -> { during_year(Current.fy_year) }
  scope :during_year, ->(year) {
    fy = Current.acp.fiscal_year_for(year)
    where('started_on >= ? AND ended_on <= ?', fy.range.min, fy.range.max)
  }
  scope :renewed, -> { where.not(renewed_at: nil) }
  scope :not_renewed, -> { where(renewed_at: nil) }
  scope :renewal_state_eq, ->(state) {
    case state.to_sym
    when :renewal_enabled
      not_renewed.where(renew: true, renewal_opened_at: nil)
    when :renewal_opened
      not_renewed.where(renew: true).where.not(renewal_opened_at: nil)
    when :renewal_canceled
      where(renew: false)
    when :renewed
      renewed
    end
  }

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[during_year renewal_state_eq]
  end

  def self.human_attribute_name(attr, *args)
    if attr == :basket_price_extra_title
      Current.acp.basket_price_extra_title
    else
      super
    end
  end

  def self.used_deliveries_cycle_ids_for(year)
    during_year(year).distinct.pluck(:deliveries_cycle_id)
  end

  def billable?
    missing_invoices_amount.positive?
  end

  def trial?
    remaning_trial_baskets_count.positive?
  end

  def trial_only?
    baskets_count == baskets.trial.count
  end

  def fiscal_year
    @fiscal_year ||= Current.acp.fiscal_year_for(started_on)
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

  def current_year?
    fy_year == Current.fy_year
  end

  def can_destroy?
    !fiscal_year.past?
  end

  def can_update?
    !fiscal_year.past?
  end

  def can_send_email?
    member.emails?
  end

  def can_member_update?
    member_updatable_baskets.any?
  end

  def member_updatable_baskets
    baskets.includes(:delivery).select(&:can_member_update?)
  end

  def member_update!(params)
    raise 'update not allowed' unless can_member_update?
    return unless params.key?(:depot_id)

    depot = Depot.find(params[:depot_id])
    params[:depot_price] = depot.price
    params = params.to_h.slice(:depot_id, :depot_price)

    transaction do
      update_columns(params)
      member_updatable_baskets.each { |b| b.update!(params) }
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
      :renewal_enabled
    end
  end

  def enable_renewal!
    raise 'cannot enable renewal on an already renewed membership' if renewed?
    raise 'renewal already enabled' if renew?

    self[:renew] = true
    save!
  end

  def open_renewal!
    unless MailTemplate.active_template(:membership_renewal)
      raise 'membership_renewal mail template not active'
    end
    raise 'already renewed' if renewed?
    raise '`renew` must be true before opening renewal' unless renew?
    unless Delivery.any_next_year?
      raise MembershipRenewal::MissingDeliveriesError, 'Deliveries for next fiscal year are missing.'
    end
    return unless can_send_email?

    MailTemplate.deliver_later(:membership_renewal,
      membership: self)
    touch(:renewal_opened_at)
  end

  def renewal_enabled?
    renew? && !renewed? && !renewal_opened_at?
  end

  def renewal_opened?
    renew? && !renewed? && renewal_opened_at?
  end

  def renew!(attrs = {})
    return if renewed?
    raise '`renew` must be true for renewing' unless renew?

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

  def renewed_membership
    member.memberships.during_year(fy_year + 1).first
  end

  def previous_membership
    member.memberships.during_year(fy_year - 1).first
  end

  def cancel!(attrs = {})
    return if canceled?
    raise 'cannot cancel an already renewed membership' if renewed?

    if Current.acp.annual_fee?
      if ActiveRecord::Type::Boolean.new.cast(attrs[:renewal_annual_fee])
        self[:renewal_annual_fee] = Current.acp.annual_fee
      end
    end
    self[:renewal_note] = attrs[:renewal_note]
    self[:renewal_opened_at] = nil
    self[:renewed_at] = nil
    self[:renew] = false
    save!
  end

  def canceled?
    !renew?
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
    super rounded_price(price.to_f)
  end

  def basket_sizes_price
    rounded_price(
      baskets
        .billable
        .sum('quantity * basket_price'))
  end

  def basket_size_price(basket_size_id)
    rounded_price(
      baskets
        .billable
        .where(basket_size_id: basket_size_id)
        .sum('quantity * basket_price'))
  end

  def baskets_price_extra
    return 0 if basket_price_extra.zero?

    rounded_price(
      baskets
        .billable
        .sum('quantity * price_extra'))
  end

  def basket_complements_price
    ids = baskets.joins(:baskets_basket_complements).pluck(:basket_complement_id).uniq
    BasketComplement.find(ids).sum { |bc| basket_complement_total_price(bc) }
  end

  def basket_complement_total_price(basket_complement)
    if basket_complement.annual_price_type?
      rounded_price(
        memberships_basket_complements
          .where(basket_complement: basket_complement)
          .sum('memberships_basket_complements.quantity * memberships_basket_complements.price'))
    else
      rounded_price(
        baskets
          .billable
          .joins(:baskets_basket_complements)
          .where(baskets_basket_complements: { basket_complement: basket_complement })
          .sum('baskets_basket_complements.quantity * baskets_basket_complements.price'))
    end
  end

  def depots_price
    baskets.pluck(:depot_id).uniq.sum { |id| depot_total_price(id) }
  end

  def depot_total_price(depot_id)
    rounded_price(
      baskets
        .billable
        .where(depot_id: depot_id)
        .sum('quantity * depot_price'))
  end

  def missing_invoices_amount
    [price - invoices_amount, 0].max
  end

  def first_delivery
    baskets.first&.delivery
  end

  def date_range
    started_on..ended_on
  end

  def basket_size
    return unless basket_size_id

    @basket_size ||= BasketSize.find(basket_size_id)
  end

  def depot
    return unless depot_id

    @depot ||= Depot.find(depot_id)
  end

  def missing_activity_participations
    [activity_participations_demanded - activity_participations_accepted, 0].max
  end

  def update_activity_participations_demanded!
    demanded = ActivityParticipationDemanded.new(self, Current.acp.activity_participations_demanded_logic).count
    if activity_participations_demanded != demanded
      update_column(:activity_participations_demanded, demanded)
    end
  end

  def update_activity_participations_accepted!
    participations = member.activity_participations.not_rejected.during_year(fiscal_year)
    invoices = member.invoices.not_canceled.activity_participation_type.during_year(fiscal_year)
    update_column(
      :activity_participations_accepted,
      participations.sum(:participants_count) + invoices.sum(:paid_missing_activity_participations))
  end

  def update_baskets_counts!
    return if destroyed?

    cols = { delivered_baskets_count: baskets.delivered.count }
    if Current.acp.trial_basket_count.positive?
      cols[:remaning_trial_baskets_count] = baskets.coming.trial.count
    end
    update_columns(cols)
  end

  def create_basket!(delivery)
    baskets.create!(
      delivery_id: delivery.id,
      basket_size_id: basket_size_id,
      basket_price: basket_price,
      quantity: basket_quantity,
      depot_id: depot_id,
      depot_price: depot_price,
      absent: member.absences.including_date(delivery.date).any?)
  end

  def update_absent_baskets!
    transaction do
      baskets.absent.update_all(absent: false)
      member.absences.each do |absence|
        baskets.between(absence.period).update_all(absent: true)
      end
      update_price_and_invoices_amount!
      cancel_outdated_invoice!
    end
  end

  def cancel_outdated_invoice!
    return if destroyed?
    return unless current_year?

    if invoices_amount > price && invoices.not_canceled.any?
      invoices.not_canceled.order(:date).last.destroy_or_cancel!
      update_price_and_invoices_amount!
    end
  end

  private

  def set_renew
    if ended_on_changed?
      self.renew = (ended_on >= Current.fy_range.max)
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

  def attributes_config_changed?
    tracked_attributes = %w[
      basket_size_id basket_price basket_quantity
      depot_id depot_price deliveries_cycle_id
    ]
    (saved_changes.keys & tracked_attributes).any?
  end

  def memberships_basket_complements_config_changed?
    @tracked_memberships_basket_complements_attributes &&
      @tracked_memberships_basket_complements_attributes !=
        memberships_basket_complements.map(&:attributes)
  end

  def create_baskets!(range = date_range)
    deliveries_cycle.deliveries_in(range).each do |delivery|
      create_basket!(delivery)
    end
  end

  def destroy_baskets!(range)
    baskets.between(range).destroy_all
  end

  def update_baskets_price_extra!
    if saved_change_to_attribute?(:basket_price_extra)
      baskets.find_each(&:update_price_extra!)
    end
  end

  def clear_member_waiting_info!
    member.update!(
      waiting_started_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      waiting_deliveries_cycle: nil,
      waiting_basket_complement_ids: nil)
  end

  def update_member_and_baskets!
    member.reload
    member.update_trial_baskets!
    update_baskets_counts!
    member.review_active_state!
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

  def update_renewal_of_previous_membership
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
    invoices.not_canceled.each(&:destroy_or_cancel!)
  end

  def only_one_per_year
    return unless member

    if member.memberships.during_year(fy_year).where.not(id: id).exists?
      errors.add(:member, :taken)
    end
  end

  def at_least_one_basket
    if date_range && date_range.min && deliveries_cycle&.deliveries_in(date_range).none?
      errors.add(:started_on, :invalid)
      errors.add(:ended_on, :invalid)
    end
  end

  def good_period_range
    if started_on && ended_on && started_on >= ended_on
      errors.add(:started_on, :before_end)
      errors.add(:ended_on, :after_start)
    end
    if ended_on && fy_year != Current.acp.fiscal_year_for(ended_on).year
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
