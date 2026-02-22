# frozen_string_literal: true

module Member::StateTransitions
  extend ActiveSupport::Concern

  included do
    after_update :review_active_state!
  end

  def validate!(validator, send_email: true)
    invalid_transition(:validate!) unless pending?

    if waiting_basket_size_id? || waiting_depot_id?
      self.waiting_started_at ||= Time.current
      self.state = Member::WAITING_STATE
    elsif !annual_fee.nil? || desired_shares_number.positive?
      self.state = Member::SUPPORT_STATE
    else
      self.state = Member::INACTIVE_STATE
    end
    self.validated_at = Time.current
    self.validator = validator
    save!

    if send_email && emails?
      MailTemplate.deliver(:member_validated, member: self)
    end
  end

  def wait!
    invalid_transition(:wait!) unless can_wait?

    self.state = Member::WAITING_STATE
    self.waiting_started_at = Time.current
    if Current.org.annual_fee_support_member_only?
      self.annual_fee = nil
    else
      self.annual_fee ||= Current.org.annual_fee
    end
    save!
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

    if emails? && (activated_at_previously_was.nil? || activated_at_previously_was < 1.week.ago)
      MailTemplate.deliver(:member_activated, member: self)
    end
  end

  def support!(annual_fee: nil)
    invalid_transition(:support!) if support?

    update!(
      state: Member::SUPPORT_STATE,
      annual_fee: annual_fee || Current.org.annual_fee,
      waiting_basket_size_id: nil,
      waiting_started_at: nil)
  end

  def deactivate!
    invalid_transition(:deactivate!) unless can_deactivate?

    attrs = {
      state: Member::INACTIVE_STATE,
      shop_depot: nil,
      annual_fee: nil,
      desired_shares_number: 0,
      waiting_started_at: nil
    }
    if shares_number.positive?
      attrs[:required_shares_number] = -1 * shares_number
    end

    update!(**attrs)
  end

  def can_wait?
    support? || inactive?
  end

  def can_deactivate?
    !inactive? && (
      waiting?
      || support?
      || (!support? && !current_or_future_membership)
    )
  end
end
