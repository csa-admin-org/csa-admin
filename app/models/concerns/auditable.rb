module Auditable
  extend ActiveSupport::Concern

  included do
    attr_accessor :audit_session
    has_many :audits, as: :auditable
    before_update :save_audited_changes!
  end

  class_methods do
    def audited_attributes(*attributes)
      const_set('AUDITED_ATTRIBUTES', attributes.map(&:to_s).freeze)
    end
  end

  private

  def save_audited_changes!
    return unless audit_session

    audited_changes = changes.slice(*self.class::AUDITED_ATTRIBUTES)
    return if audited_changes.none?

    audits.create!(
      session: audit_session,
      audited_changes: audited_changes)
  end
end
