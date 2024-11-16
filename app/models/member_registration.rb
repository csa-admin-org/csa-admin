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

    existing_member.assign_attributes(@permitted_params)
    if support_only? && existing_member.inactive?
      existing_member.support!
      @member = existing_member
      true
    elsif existing_member.can_wait?
      existing_member.wait!
      @member = existing_member
      notify_admins!(existing: true)
      true
    end
  end

  private

  def notify_admins!(existing: false)
    Admin.notify!(:new_registration, member: @member, existing: existing)
  end

  def support_only?
    @permitted_params[:waiting_basket_size_id] == "0"
  end

  def existing_member
    @existing_member ||= begin
      members = @member.emails_array.map { |email|
        Member.including_email(email).first
      }.compact.uniq
      raise MultipleMatchingMembersError if members.many?

      members.first
    end
  end
end
