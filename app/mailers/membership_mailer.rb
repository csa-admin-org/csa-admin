class MembershipMailer < ApplicationMailer
  include Templatable

  def last_trial_basket_email
    basket = params[:basket]
    membership = params[:membership] || basket.membership
    member = params[:member] || membership.member
    template_mail(member,
      'basket' => Liquid::BasketDrop.new(basket),
      'member' => Liquid::MemberDrop.new(member),
      'membership' => Liquid::MembershipDrop.new(membership))
  end

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
