module Auditable
  extend ActiveSupport::Concern

  included do
    class_attribute :auditable_attributes, default: []

    has_many :audits, as: :auditable, dependent: :delete_all

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
    return if audited_changes.none?

    self.audits.build(
      session: Current.session,
      audited_changes: audited_changes)
  end
end
