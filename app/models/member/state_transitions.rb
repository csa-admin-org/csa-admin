# frozen_string_literal: true

module Member::StateTransitions
  extend ActiveSupport::Concern

  included do
    after_update :review_active_state!
  end

  def validate!(validator, send_email: true)
    invalid_transition(:validate!) unless pending?

    result = transaction { validate_pending_member!(validator) }
    deliver_validation_email! if result == true && send_email
    result
  end

  def review_active_state!
    return if pending?

    if current_or_future_membership || shop_depot
      activate! unless active?
    elsif active?
      if last_membership&.renewal_annual_fee&.positive?
        support!(annual_fee: last_membership.renewal_annual_fee)
      elsif shares_number.positive?
        support!
      else
        deactivate!
      end
    end
  end

  def activate!
    invalid_transition(:activate!) unless current_or_future_membership || shop_depot
    return if active?

    self.state = Member::ACTIVE_STATE
    unless Current.org.annual_fee_support_member_only?
      self.annual_fee ||= Current.org.annual_fee
    end
    self.activated_at = Time.current
    save!

    if send_member_activated_email?
      MailTemplate.deliver(:member_activated, member: self)
    elsif send_member_shop_depot_activated_email?
      MailTemplate.deliver(:member_shop_depot_activated, member: self)
    end
  end

  def support!(annual_fee: nil)
    invalid_transition(:support!) if support?

    assign_attributes(
      state: Member::SUPPORT_STATE,
      annual_fee: annual_fee || Current.org.annual_fee)
    clear_waiting_membership_attributes
    save!
  end

  def deactivate!
    invalid_transition(:deactivate!) unless can_deactivate?

    attrs = {
      state: Member::INACTIVE_STATE,
      shop_depot: nil,
      shop_delivery_cycle: nil,
      annual_fee: nil,
      desired_shares_number: 0,
      waiting_started_at: nil
    }
    if shares_number.positive?
      attrs[:required_shares_number] = -1 * shares_number
    end

    assign_attributes(**attrs)
    clear_waiting_membership_attributes
    save!
  end

  def can_deactivate?
    !inactive? && (
      waiting?
      || support?
      || (!support? && !current_or_future_membership)
    )
  end

  private

  def validate_pending_member!(validator)
    mark_as_validated_by(validator)
    membership_request? ? validate_membership_request! : validate_without_membership_request!
  end

  def mark_as_validated_by(validator)
    self.validated_at = Time.current
    self.validator = validator
  end

  def validate_membership_request!
    ensure_complete_membership_request!
    return validate_into_waiting_list! if waiting_list_validation?

    validate_with_direct_membership!
  end

  def validate_into_waiting_list!
    self.waiting_started_at ||= Time.current
    self.state = Member::WAITING_STATE
    apply_waiting_annual_fee
    save!
    true
  end

  def validate_with_direct_membership!
    self.state = Member::INACTIVE_STATE
    save!
    create_membership_from_waiting_request!
  end

  def validate_without_membership_request!
    clear_waiting_membership_attributes
    self.state = support_after_validation? ? Member::SUPPORT_STATE : Member::INACTIVE_STATE
    save!
    !active?
  end

  def waiting_list_validation?
    Current.org.waiting_list? && !direct_membership_start_requested?
  end

  def support_after_validation?
    !annual_fee.nil? || desired_shares_number.positive?
  end

  def deliver_validation_email!
    return unless emails?

    MailTemplate.deliver(:member_validated, member: self)
  end

  def send_member_activated_email?
    current_or_future_membership && send_activation_email?
  end

  def send_member_shop_depot_activated_email?
    Current.org.feature?(:shop) &&
      shop_depot &&
      !current_or_future_membership &&
      send_activation_email?
  end

  def send_activation_email?
    emails? &&
      (activated_at_previously_was.nil? || activated_at_previously_was < 1.week.ago)
  end
end
