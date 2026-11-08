# frozen_string_literal: true

class MemberRegistration
  class MultipleMatchingMembersError < StandardError; end

  attr_reader :member

  def initialize(member, permitted_params, promotion: nil)
    @member = member
    @permitted_params = permitted_params
    @promotion = promotion
  end

  def claimed_promotion?
    @claimed_promotion
  end

  # Shop-only leaves the cookie for a later membership registration. Everything
  # else that did not claim, including an invalid code, drops it.
  def clear_promotion_cookie?
    !claimed_promotion? && !shop_only?
  end

  def save
    return save_existing! if @member.persisted?

    prepare_support_only_registration! if support_only?
    if @member.save
      claim_promotion!
      notify_admins!
      return true
    end
    if @member.errors.size > 1 || !@member.errors.of_kind?(:emails, :taken)
      @member.errors.delete(:emails, :taken)
      return
    end

    # existing_member is nil when the email belongs to a discarded member
    # (kept out of the kept scope). In this case, the email is still "taken"
    # until anonymization clears it.
    return unless existing_member
    return unless existing_member.inactive? || existing_member.support?

    public_create = @member.public_create
    @member = existing_member
    @member.public_create = public_create
    save_existing!
  end

  private

  def save_existing!
    return unless @member.inactive? || @member.support?

    @member.assign_attributes(@permitted_params)
    prepare_support_only_reregistration! if support_only?
    @member.state = Member::PENDING_STATE
    @member.validated_at = nil
    @member.validator = nil
    @member.waiting_started_at = nil

    if @member.save
      claim_promotion!
      cancel_last_membership_open_renewal!
      notify_admins!(existing: true)
      true
    end
  end

  def cancel_last_membership_open_renewal!
    membership = @member.last_membership
    return unless membership&.renewal_opened?

    membership.cancel!
  end

  def notify_admins!(existing: false)
    Admin.notify!(:new_registration, member: @member, existing: existing)
  end

  # Shop-only, support-only, and a salary basket have nothing to invoice.
  # An open membership is a renewal, not a new claim. A code that is no
  # longer redeemable is ignored so the registration still succeeds.
  def claim_promotion!
    return unless claimable_promotion?

    PromotionClaim.claim!(@member, @promotion)
    @member.update_column(:waiting_promotion_id, @promotion.id)
    @claimed_promotion = true
  rescue PromotionClaim::Error
    nil
  end

  def claimable_promotion?
    return false if @promotion.nil? || !@promotion.redeemable?
    return false if support_only? || shop_only?
    return false unless Promotion.acceptable_target?(@member)
    return false if @member.current_year_membership || @member.future_membership

    true
  end

  def shop_only?
    Current.org.member_form_mode == "shop"
  end

  def support_only?
    @permitted_params[:waiting_basket_size_id].to_s == "0"
  end

  def prepare_support_only_registration!
    @member.waiting_price_reduction_id = nil
  end

  def prepare_support_only_reregistration!
    @member.waiting_depot_id = nil
    @member.waiting_delivery_cycle_id = nil
    @member.waiting_basket_price_extra = nil
    @member.waiting_activity_participations_demanded_annually = nil
    @member.waiting_billing_year_division = nil
    @member.waiting_basket_complement_ids = []
    @member.waiting_alternative_depot_ids = []
    @member.waiting_price_reduction_id = nil
    @member.annual_fee ||= Current.org.annual_fee if Current.org.feature?("annual_fee")
  end

  def existing_member
    @existing_member ||= begin
      # Only match kept (non-discarded) members for reuse.
      # Discarded members keep their emails "taken" until anonymization clears them.
      emails = @member.emails_array
      members = if emails.empty?
        []
      else
        emails
          .map { |email| Member.kept.including_email(email) }
          .reduce(&:or)
          .to_a
          .uniq
      end
      raise MultipleMatchingMembersError if members.many?

      members.first
    end
  end
end
