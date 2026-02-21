# frozen_string_literal: true

class MembershipMailer < ApplicationMailer
  include Templatable

  def renewal_email
    membership = params[:membership]
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-renewal",
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def renewal_reminder_email
    membership = params[:membership]
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-renewal-reminder",
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def absence_included_reminder_email
    membership = params[:membership]
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "absence-included-reminder",
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end
end
