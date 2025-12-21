# frozen_string_literal: true

class MembershipMailer < ApplicationMailer
  include Templatable

  def initial_basket_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-initial-basket",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def final_basket_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-final-basket",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def first_basket_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-first-basket",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def last_basket_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-last-basket",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def second_last_trial_basket_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-second-last-trial-basket",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def last_trial_basket_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "membership-last-trial-basket",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

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
end
