# frozen_string_literal: true

class HomeDeliveryAddress < ApplicationRecord
  include Sessionable
  include NormalizedString

  belongs_to :member
  has_many :home_delivery_address_deliveries,
    dependent: :destroy,
    inverse_of: :home_delivery_address
  has_many :deliveries, through: :home_delivery_address_deliveries

  normalized_string_attributes :name, :street, :city, :zip, :note

  attr_accessor :member_managed

  validates :name, :street, :zip, :city, presence: true
  validates :delivery_ids, presence: true, if: :member_managed
  validate :deliveries_must_be_eligible
  validate :deliveries_not_already_taken
  validate :address_must_stay_frozen

  def delivery_ids=(ids)
    ids = Array(ids).compact_blank.map(&:to_i)
    ids |= locked_delivery_ids if persisted? && member.present?
    super(ids)
  end

  scope :for_delivery, ->(delivery) {
    joins(:home_delivery_address_deliveries)
      .where(home_delivery_address_deliveries: { delivery_id: delivery.id })
  }

  def self.for(member, delivery)
    return unless member && delivery

    by_member_id_for(delivery, [ member ]).values.first
  end

  def self.by_member_id_for(delivery, members)
    return {} unless delivery&.id

    member_ids = Array(members).filter_map { |m| m.respond_to?(:id) ? m.id : m }
    return {} if member_ids.empty?

    eligible_member_ids = Basket
      .joins(:depot, :membership)
      .where(memberships: { member_id: member_ids }, delivery_id: delivery.id)
      .where(depots: { delivery_sheets_mode: "home_delivery" })
      .distinct
      .pluck("memberships.member_id")

    return {} if eligible_member_ids.empty?

    for_delivery(delivery)
      .where(member_id: eligible_member_ids)
      .index_by(&:member_id)
  end

  def self.eligible_baskets_for(member, keep_delivery_ids: [])
    keep_delivery_ids = Array(keep_delivery_ids).compact
    baskets = member.baskets
      .joins(:depot, :delivery)
      .where(depots: { delivery_sheets_mode: "home_delivery" })
      .merge(Delivery.coming)

    if keep_delivery_ids.any?
      baskets.where("baskets.state != ? OR baskets.delivery_id IN (?)", "absent", keep_delivery_ids)
    else
      baskets.not_absent
    end
  end

  def self.taken_delivery_ids_for(member, except: nil)
    rel = HomeDeliveryAddressDelivery.where(member_id: member.id)
    rel = rel.where.not(home_delivery_address_id: except.id) if except&.persisted?
    rel.pluck(:delivery_id)
  end

  def self.visible_on_member?(member)
    member.home_delivery_addresses.exists? || eligible_baskets_for(member).exists?
  end

  def self.member_deadline_date
    Current.org.basket_update_limit_in_days.to_i.days.from_now.to_date
  end

  def self.member_deadline_ok?(delivery)
    delivery.date >= member_deadline_date
  end

  def self.member_eligible_baskets_for(member, keep_delivery_ids: [])
    keep_delivery_ids = Array(keep_delivery_ids).compact
    baskets = eligible_baskets_for(member, keep_delivery_ids: keep_delivery_ids)
    deadline = member_deadline_date
    if keep_delivery_ids.any?
      baskets.merge(Delivery.where("date >= ? OR deliveries.id IN (?)", deadline, keep_delivery_ids))
    else
      baskets.merge(Delivery.where(date: deadline..))
    end
  end

  def self.can_member_create_for?(basket)
    return false unless basket
    return false if basket.absent?
    return false unless basket.depot.delivery_sheets_mode == "home_delivery"

    member_deadline_ok?(basket.delivery)
  end

  def self.by_delivery_id_for_member(member)
    where(member_id: member.id).includes(:deliveries).each_with_object({}) do |overlay, hash|
      overlay.deliveries.each { |delivery| hash[delivery.id] = overlay }
    end
  end

  def persisted_delivery_ids
    return [] unless persisted?

    HomeDeliveryAddressDelivery.where(home_delivery_address_id: id).pluck(:delivery_id)
  end

  def can_member_update?
    deliveries.any? { |delivery| self.class.member_deadline_ok?(delivery) }
  end

  def can_member_destroy?
    can_member_update? && frozen_member_delivery_ids.empty?
  end

  def frozen_member_delivery_ids
    return [] unless persisted?

    HomeDeliveryAddressDelivery
      .where(home_delivery_address_id: id)
      .joins(:delivery)
      .where(deliveries: { date: ...self.class.member_deadline_date })
      .pluck(:delivery_id)
  end

  def next_delivery_date
    deliveries.filter_map { |d| d.date if d.date >= Date.current }.min
  end

  def display_address
    [ name, street, "#{zip} #{city}" ].compact_blank.join(", ")
  end

  def sheet_address
    [ name, street, "#{zip} #{city}" ].compact_blank.join("\n")
  end

  def sheet_note
    note.presence || member.delivery_note
  end

  private

  def locked_delivery_ids
    return frozen_member_delivery_ids if member_managed

    persisted_delivery_ids - self.class.eligible_baskets_for(
      member,
      keep_delivery_ids: persisted_delivery_ids).map(&:delivery_id)
  end

  def deliveries_must_be_eligible
    return if deliveries.empty? || member.blank?

    keep_ids = persisted_delivery_ids
    picker = member_managed ? :member_eligible_baskets_for : :eligible_baskets_for
    eligible_ids = self.class.public_send(picker, member, keep_delivery_ids: keep_ids).map(&:delivery_id)
    allowed_ids = (keep_ids + eligible_ids).uniq
    invalid = deliveries.reject { |d| allowed_ids.include?(d.id) }
    return if invalid.empty?

    errors.add(:delivery_ids, :not_eligible)
  end

  def deliveries_not_already_taken
    return if deliveries.empty? || member.blank?

    taken = HomeDeliveryAddressDelivery.where(member_id: member_id, delivery_id: deliveries.map(&:id))
    taken = taken.where.not(home_delivery_address_id: id) if persisted?
    return unless taken.exists?

    errors.add(:delivery_ids, :taken)
  end

  def address_must_stay_frozen
    return unless member_managed
    return if frozen_member_delivery_ids.empty?
    return unless (changed & %w[name street zip city note]).any?

    errors.add(:base, :frozen)
  end
end
