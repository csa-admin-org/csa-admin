# frozen_string_literal: true

module Auditable
  extend ActiveSupport::Concern

  included do
    class_attribute :auditable_attributes, default: []

    has_many :audits, as: :auditable, dependent: :delete_all

    # Alias for ActiveAdmin compatibility when using `as: "ModelAudit"` resources.
    # ActiveAdmin's `belongs_to` expects an association named after the resource
    # (e.g., member_audits for MemberAudit), so we define it as an alias.
    model_name_underscore = name.underscore.tr("/", "_")
    has_many :"#{model_name_underscore}_audits", class_name: "Audit", as: :auditable

    before_save :audit_changes!
  end

  class_methods do
    def audited_attributes(*attrs)
      self.auditable_attributes = attrs.map(&:to_s).freeze
    end
  end

  private

  def audit_changes!
    audited_changes = changes.slice(*self.class.auditable_attributes)
    audited_changes.transform_values! { |change_pair|
      change_pair.map { |v| normalize_audited_value(v) }
    }
    audited_changes.reject! { |_, change_pair|
      change_pair.all?(&:blank?) || change_pair.uniq.size == 1
    }

    audited_changes.merge!(audited_nested_changes)

    return if audited_changes.none?

    self.audits.build(
      session: Current.session,
      audited_changes: audited_changes,
      metadata: audit_metadata)
  end

  # IMPORTANT: When Auditable is included inside an Auditing concern's `included`
  # block, this method must be defined in a prepended module to ensure it takes
  # precedence over this default implementation. See existing Auditing concerns
  # (e.g., Membership::Auditing) for the correct pattern.
  def audited_nested_changes
    {}
  end

  def audit_metadata
    {}
  end

  def normalize_audited_value(value)
    case value
    when String
      value.strip.presence
    when Hash
      value.values.any?(&:present?) ? value : nil
    else
      value
    end
  end
end
