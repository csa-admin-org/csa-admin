# frozen_string_literal: true

# Concern grouping all SEPA mandate logic on Member.
#
# Each SEPA mandate is an append-only SEPAMandate record — edits always
# create a new row rather than updating the existing one. The current state
# is simply the most-recently-created mandate. Evidence and audit history are
# intrinsic to the table itself.
#
# Kept separate from Member::Billing so SEPA evolves independently of
# generic billing-address concerns.
module Member::SEPA
  extend ActiveSupport::Concern

  included do
    has_many :sepa_mandates, class_name: "SEPAMandate"
    has_one :current_sepa_mandate,
      -> { order(created_at: :desc, id: :desc) },
      class_name: "SEPAMandate"

    scope :sepa, -> { joins(:sepa_mandates).where(sepa_disabled_at: nil).distinct }
    scope :not_sepa, -> {
      left_outer_joins(:sepa_mandates)
        .where("members.sepa_disabled_at IS NOT NULL OR sepa_mandates.id IS NULL")
        .distinct
    }
    scope :sepa_eq, ->(bool) { ActiveRecord::Type::Boolean.new.cast(bool) ? sepa : not_sepa }

    before_validation :apply_pending_sepa_state_changes

    # Admin form: nested attributes create a new SEPAMandate instead of
    # updating member columns. The reject_if guard skips creation when the
    # form is submitted without any SEPA changes.
    accepts_nested_attributes_for :sepa_mandates, reject_if: :duplicate_sepa_mandate?
  end

  def sepa?
    current_sepa_mandate.present? && !sepa_disabled?
  end

  def sepa_disabled?
    current_sepa_mandate.present? && sepa_disabled_at?
  end

  def can_disable_sepa?
    current_sepa_mandate.present? && !sepa_disabled?
  end

  def disable_sepa!
    return if !current_sepa_mandate || sepa_disabled?

    update!(sepa_disabled_at: Time.current)
  end

  def enable_sepa!
    return unless sepa_disabled?

    update!(sepa_disabled_at: nil)
  end

  # Delegates to the current mandate so callers can still use member.iban
  # and member.iban_formatted without knowing about SEPAMandate.
  def iban
    current_sepa_mandate&.iban
  end

  def iban?
    iban.present?
  end

  def iban_formatted
    current_sepa_mandate&.iban_formatted
  end

  private

  # Used by accepts_nested_attributes_for to skip creating a new mandate
  # when the admin saves the member form without changing any SEPA field.
  # Returns true (reject) when:
  # - IBAN is blank (disable SEPA when currently active), OR
  # - all submitted values match the current mandate (re-enable when disabled).
  def duplicate_sepa_mandate?(attrs)
    submitted_iban = SEPAMandate.normalize_value_for(:iban, attrs[:iban])

    if submitted_iban.blank?
      @pending_disable_sepa = current_sepa_mandate.present? && !sepa_disabled?
      return true
    end

    current = current_sepa_mandate
    return false unless current

    umr = attrs[:umr].to_s.strip
    signed_on = begin
      Date.parse(attrs[:signed_on].to_s) if attrs[:signed_on].present?
    rescue ArgumentError
      nil
    end

    unchanged = submitted_iban == current.iban &&
      (umr.blank? || umr == current.umr) &&
      (signed_on.nil? || signed_on == current.signed_on)

    @pending_enable_sepa = true if unchanged && sepa_disabled?
    unchanged
  end

  def apply_pending_sepa_state_changes
    self.sepa_disabled_at = Time.current if @pending_disable_sepa
    self.sepa_disabled_at = nil if @pending_enable_sepa
    @pending_disable_sepa = false
    @pending_enable_sepa = false
  end
end
