class MembershipMailer < ApplicationMailer
  include Templatable

  def renewal_email
    membership = params[:membership]
    member = params[:member] || membership.member
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'membership' => Liquid::MembershipDrop.new(membership))
  end

  def renewal_reminder_email
    membership = params[:membership]
    member = params[:member] || membership.member
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'membership' => Liquid::MembershipDrop.new(membership))
  end
end
