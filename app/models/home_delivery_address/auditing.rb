# frozen_string_literal: true

module HomeDeliveryAddress::Auditing
  extend ActiveSupport::Concern

  SNAPSHOT_ATTRIBUTES = %w[id name street zip city note].freeze

  module CollectionTracking
    def delivery_ids=(ids)
      capture_member_audit_before
      super
    end

    def deliveries=(records)
      capture_member_audit_before
      super
    end
  end

  included do
    prepend CollectionTracking

    before_save :capture_member_audit_before
    after_commit :record_member_audit, on: %i[create update]
    after_rollback :clear_member_audit_snapshots
    before_destroy :capture_member_audit_before, prepend: true
    after_destroy :record_member_audit_destroy
  end

  private

  def capture_member_audit_before
    return if defined?(@member_audit_before)

    @member_audit_before = new_record? ? nil : database_audit_snapshot
  end

  def record_member_audit
    record_member_audit_change(@member_audit_before, current_audit_snapshot)
  ensure
    clear_member_audit_snapshots
  end

  def record_member_audit_destroy
    return if skip_member_audit_destroy?

    record_member_audit_change(@member_audit_before || database_audit_snapshot, nil)
  ensure
    clear_member_audit_snapshots
  end

  def skip_member_audit_destroy?
    member.nil? || member.destroyed? || member.marked_for_destruction? || destroyed_by_association
  end

  def record_member_audit_change(before, after)
    return unless member
    return if normalize_audit_snapshot(before) == normalize_audit_snapshot(after)

    member.audits.create!(
      session: Current.session,
      audited_changes: { "home_delivery_address" => [ before, after ] })
  end

  def current_audit_snapshot
    snapshot_from(
      attributes: SNAPSHOT_ATTRIBUTES.index_with { |attr| public_send(attr) },
      delivery_ids: delivery_ids)
  end

  def database_audit_snapshot
    snapshot_from(
      attributes: SNAPSHOT_ATTRIBUTES.index_with { |attr|
        attr == "id" ? id : attribute_in_database(attr)
      },
      delivery_ids: persisted_delivery_ids)
  end

  def snapshot_from(attributes:, delivery_ids:)
    attributes.merge("delivery_ids" => Array(delivery_ids).map(&:to_i).sort)
  end

  def normalize_audit_snapshot(snapshot)
    return if snapshot.nil?

    snapshot = snapshot.stringify_keys
    snapshot.merge("delivery_ids" => Array(snapshot["delivery_ids"]).map(&:to_i).sort)
  end

  def clear_member_audit_snapshots
    remove_instance_variable(:@member_audit_before) if defined?(@member_audit_before)
  end
end
