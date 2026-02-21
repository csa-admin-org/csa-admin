# frozen_string_literal: true

class MembershipMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def renewal_email = membership_email
  def renewal_reminder_email = membership_email
  def absence_included_reminder_email = membership_email

  private

  def set_context
    @membership = params[:membership]
    @member = @membership.member
  end

  def membership_email
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "membership" => Liquid::MembershipDrop.new(@membership))
  end
end
