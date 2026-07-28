# frozen_string_literal: true

module Membership::MemberUpdatable
  extend ActiveSupport::Concern

  def can_member_update?
    return false unless can_member_update_depot? ||
                        Current.org.membership_complements_update_allowed?

    member_updatable_baskets.any?
  end

  def can_member_update_depot?
    return false unless Current.org.membership_depot_update_allowed?

    @can_member_update_depot ||= member_visible_depot_ids.many?
  end

  def member_updatable_baskets
    baskets.includes(:delivery).select(&:can_member_update?)
  end

  def member_updatable_depot_ids(extra_depot_id: nil)
    (member_visible_depot_ids + [ depot_id, extra_depot_id ]).compact.uniq
  end

  def find_member_updatable_depot!(depot_id, extra_depot_id: nil)
    id = depot_id.to_i
    raise "update not allowed" unless member_updatable_depot_ids(extra_depot_id: extra_depot_id).include?(id)

    Depot.find(id)
  end

  def member_update!(params)
    raise "update not allowed" unless can_member_update?
    return unless params.key?(:depot_id)
    raise "update not allowed" unless can_member_update_depot?

    apply_member_depot_update!(find_member_updatable_depot!(params[:depot_id]))
  end

  private

  def apply_member_depot_update!(depot)
    attrs = { depot_id: depot.id, depot_price: depot.price }
    return if depot_id == attrs[:depot_id] && depot_price == attrs[:depot_price]

    transaction do
      previous = slice(:depot_id, :depot_price).symbolize_keys
      write_member_depot_columns!(attrs)
      updatable = update_member_updatable_baskets!(attrs)
      audit_member_depot_update!(previous, attrs, updatable)
    end
  end

  def write_member_depot_columns!(attrs)
    # Skip callbacks: update! would rebuild all baskets from new_config_from.
    update_columns(attrs)
    @depot = nil
  end

  def update_member_updatable_baskets!(attrs)
    member_updatable_baskets.tap do |updatable|
      updatable.each { |b| b.update!(attrs) }
      reapply_alternate_depot!(updatable) if alternate_depot_id?
    end
  end

  def member_visible_depot_ids
    @member_visible_depot_ids ||=
      Depot.visible
        .joins(:delivery_cycles)
        .where(delivery_cycles: { id: delivery_cycle_id })
        .distinct
        .pluck(:id)
  end

  def audit_member_depot_update!(previous, attrs, updatable)
    changes = attrs.filter_map { |key, after|
      before = previous[key]
      [ key.to_s, [ before, after ] ] unless before == after
    }.to_h
    return if changes.empty?

    audits.create!(
      session: Current.session,
      audited_changes: changes,
      metadata: {
        "new_config_from" => (updatable.first&.delivery&.date || Date.current).to_s
      })
  end
end
