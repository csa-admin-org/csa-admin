# frozen_string_literal: true

class MemberRegistration
  class MultipleMatchingMembersError < StandardError; end

  attr_reader :member

  def initialize(member, permitted_params)
    @member = member
    @permitted_params = permitted_params
  end

  def save
    if @member.save
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
    @member.assign_attributes(@permitted_params)
    @member.public_create = public_create
    prepare_support_only_reregistration! if support_only?
    @member.state = Member::PENDING_STATE
    @member.validated_at = nil
    @member.validator = nil
    @member.waiting_started_at = nil

    if @member.save
      notify_admins!(existing: true)
      true
    end
  end

  private

  def notify_admins!(existing: false)
    Admin.notify!(:new_registration, member: @member, existing: existing)
  end

  def support_only?
    @permitted_params[:waiting_basket_size_id].to_s == "0"
  end

  def prepare_support_only_reregistration!
    @member.waiting_depot_id = nil
    @member.waiting_delivery_cycle_id = nil
    @member.waiting_basket_price_extra = nil
    @member.waiting_activity_participations_demanded_annually = nil
    @member.waiting_billing_year_division = nil
    @member.waiting_basket_complement_ids = []
    @member.waiting_alternative_depot_ids = []
    @member.annual_fee ||= Current.org.annual_fee if Current.org.feature?("annual_fee")
  end

  def existing_member
    @existing_member ||= begin
      # Only match kept (non-discarded) members for reuse.
      # Discarded members keep their emails "taken" until anonymization clears them.
      members = @member.emails_array.map { |email|
        Member.kept.including_email(email).first
      }.compact.uniq
      raise MultipleMatchingMembersError if members.many?

      members.first
    end
  end
end
