# frozen_string_literal: true

module Member::Waiting
  extend ActiveSupport::Concern

  included do
    attribute :waiting_membership_started_on, :date

    belongs_to :waiting_basket_size, class_name: "BasketSize", optional: true
    belongs_to :waiting_depot, class_name: "Depot", optional: true
    belongs_to :waiting_delivery_cycle, class_name: "DeliveryCycle", optional: true
    has_and_belongs_to_many :waiting_alternative_depots,
      class_name: "Depot",
      join_table: "members_waiting_alternative_depots",
      optional: true
    has_many :members_basket_complements, dependent: :destroy
    has_many :waiting_basket_complements,
      source: :basket_complement,
      through: :members_basket_complements

    accepts_nested_attributes_for :members_basket_complements, allow_destroy: true

    scope :with_waiting_depots_eq, ->(depot_id) {
      left_joins(:members_waiting_alternative_depots).where(<<-SQL, depot_id: depot_id).distinct
        members.waiting_depot_id = :depot_id OR
        members_waiting_alternative_depots.depot_id = :depot_id
      SQL
    }

    before_validation :set_default_waiting_billing_year_division
    before_validation :set_default_waiting_delivery_cycle
    before_validation :move_inactive_to_waiting_list

    validates :waiting_billing_year_division,
      inclusion: { in: proc { Current.org.billing_year_divisions }, allow_nil: true },
      on: :create,
      if: :public_create
    validates :waiting_billing_year_division,
      inclusion: { in: Organization.billing_year_divisions, allow_nil: true }
    validates :waiting_basket_size, inclusion: { in: proc { BasketSize.all }, allow_nil: true }, on: :create
    validates :waiting_basket_size_id, presence: true, if: :waiting_depot, on: :create
    validates :waiting_activity_participations_demanded_annually, numericality: true, allow_nil: true
    validates :waiting_activity_participations_demanded_annually,
      numericality: {
        greater_than_or_equal_to: -> { Current.org.activity_participations_form_min || 0 },
        less_than_or_equal_to: -> { Current.org.activity_participations_form_max || 1000 },
        allow_nil: true
      },
      if: -> { public_create && Current.org.feature?("activity") }
    validates :waiting_basket_size_id, presence: true,
      on: :create,
      if: -> { public_create && Current.org.member_form_mode == "membership" && BasketSize.visible.exists? }
    validates :waiting_depot, inclusion: { in: proc { Depot.all }, allow_nil: true }, on: :create
    validates :waiting_depot_id, presence: true, if: :waiting_basket_size, on: :create
    validate :unique_waiting_basket_complement_id
    validate :waiting_membership_started_on_required_for_admin_create, on: :create
    validate :complete_waiting_list_request_for_inactive_member, on: :update
  end

  class_methods do
    def waiting_list_available?
      Current.org.waiting_list? || waiting.exists?
    end
  end

  def membership_request?
    waiting_basket_size_id.to_i.positive? ||
      waiting_depot_id? ||
      waiting_delivery_cycle_id? ||
      waiting_basket_price_extra.present? ||
      waiting_activity_participations_demanded_annually.present? ||
      members_basket_complements.reject(&:marked_for_destruction?).any? ||
      waiting_alternative_depot_ids.any?
  end

  def complete_membership_request?
    membership_request? && missing_membership_request_attributes.empty?
  end

  def direct_membership_start_requested?
    waiting_membership_started_on.present?
  end

  def waiting_delivery_cycle_next_start_on
    return unless (delivery = waiting_delivery_cycle&.next_delivery)

    [
      Date.current,
      delivery.fy_range.min,
      delivery.date.beginning_of_week
    ].max
  end

  def waiting_membership_start_on
    waiting_membership_started_on.presence || waiting_delivery_cycle_next_start_on
  end

  def waiting_membership_end_on(started_on = waiting_membership_start_on)
    Current.org.fiscal_year_for(started_on).end_of_year if started_on
  end

  def create_membership_from_waiting_request!(started_on: waiting_membership_start_on)
    ensure_complete_membership_request!
    unless started_on
      errors.add(:waiting_delivery_cycle, :no_upcoming_delivery)
      raise ActiveRecord::RecordInvalid, self
    end

    memberships.build.tap do |membership|
      membership.populate_from_waiting_member!(self)
      membership.started_on = started_on
      membership.ended_on = waiting_membership_end_on(started_on)
      membership.save!
    rescue ActiveRecord::RecordInvalid => e
      raise if e.record == self

      e.record.errors.full_messages.each { |message| errors.add(:base, message) }
      raise ActiveRecord::RecordInvalid, self
    end
  end

  def can_create_membership?
    waiting? && complete_membership_request? && waiting_delivery_cycle_next_start_on.present?
  end

  def validation_creates_membership?
    pending? &&
      complete_membership_request? &&
      !(Current.org.waiting_list? && !direct_membership_start_requested?) &&
      waiting_membership_start_on.present?
  end

  def validation_waiting_membership_no_delivery?
    pending? &&
      membership_request? &&
      !(Current.org.waiting_list? && !direct_membership_start_requested?) &&
      waiting_membership_start_on.blank?
  end

  def activation_waiting_membership_no_delivery?
    waiting? && complete_membership_request? && waiting_delivery_cycle_next_start_on.blank?
  end

  def clear_waiting_membership_attributes
    assign_attributes(
      waiting_started_at: nil,
      waiting_basket_size_id: nil,
      waiting_depot_id: nil,
      waiting_delivery_cycle_id: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil,
      waiting_membership_started_on: nil)
    self.waiting_basket_complement_ids = []
    self.waiting_alternative_depot_ids = []
  end

  def clear_waiting_membership_attributes!(validate: true)
    clear_waiting_membership_attributes
    save!(validate: validate)
  end

  private

  def set_default_waiting_billing_year_division
    if (waiting_basket_size_id? && !waiting_billing_year_division?)
        || (waiting_billing_year_division? && !waiting_billing_year_division.in?(Current.org.billing_year_divisions))
      self[:waiting_billing_year_division] = Current.org.billing_year_divisions.last
    end
  end

  def set_default_waiting_delivery_cycle
    return unless waiting_basket_size
    return unless waiting_depot

    self.waiting_delivery_cycle ||= waiting_depot.delivery_cycles.primary
  end

  def waiting_membership_started_on_required_for_admin_create
    return if public_create
    return if Current.org.waiting_list?
    return unless membership_request?
    return if waiting_membership_started_on.present?

    errors.add(:waiting_membership_started_on, :blank)
  end

  def ensure_complete_membership_request!
    missing_membership_request_attributes.each do |attr|
      errors.add(attr, :blank)
    end
    raise ActiveRecord::RecordInvalid, self if errors.any?
  end

  def missing_membership_request_attributes
    [].tap do |attrs|
      attrs << :waiting_basket_size if !waiting_basket_size_id.to_i.positive?
      attrs << :waiting_depot if !waiting_depot_id?
      attrs << :waiting_delivery_cycle if !waiting_delivery_cycle_id?
      attrs << :waiting_billing_year_division if !waiting_billing_year_division?
    end
  end

  def complete_waiting_list_request_for_inactive_member
    return unless Current.org.waiting_list?
    return unless inactive?
    return unless membership_request?

    missing_membership_request_attributes.each do |attr|
      errors.add(attr, :blank)
    end
  end

  def move_inactive_to_waiting_list
    return unless Current.org.waiting_list?
    return unless inactive?
    return if state_change_to_be_saved&.first == Member::PENDING_STATE
    return unless complete_membership_request?

    self.state = Member::WAITING_STATE
    self.waiting_started_at ||= Time.current
    apply_waiting_annual_fee
  end

  def apply_waiting_annual_fee
    if Current.org.annual_fee_support_member_only?
      self.annual_fee = nil
    else
      self.annual_fee ||= Current.org.annual_fee
    end
  end

  def unique_waiting_basket_complement_id
    used_basket_complement_ids = []
    members_basket_complements.each do |mbc|
      if mbc.basket_complement_id.in?(used_basket_complement_ids)
        mbc.errors.add(:basket_complement_id, :taken)
        errors.add(:base, :invalid)
      end
      used_basket_complement_ids << mbc.basket_complement_id
    end
  end
end
