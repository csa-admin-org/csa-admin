# frozen_string_literal: true

class Audit < ApplicationRecord
  belongs_to :session, optional: true
  belongs_to :auditable, polymorphic: true

  scope :reversed, -> { order(created_at: :desc) }

  # Returns audits that represent changes after the initial creation.
  # Excludes audits created within 1 second of the auditable's creation,
  # which are typically the initial "create" audit.
  scope :relevant_for, ->(auditable) {
    where(auditable: auditable)
      .where(created_at: (auditable.created_at + 1.second)..)
  }

  def self.find_change_of(attr, **opts)
    all
      .includes(session: [ :member, :admin ])
      .find { |audit|
        next unless change = audit.changes[attr]

        checks = []
        checks << (change.first == opts[:from]) if opts.key?(:from)
        checks << (change.last == opts[:to]) if opts.key?(:to)
        checks.compact!
        checks.present? && checks.all?
      }
  end

  def actor
    session&.owner || System.instance
  end

  def changes
    audited_changes.with_indifferent_access
  end
end
