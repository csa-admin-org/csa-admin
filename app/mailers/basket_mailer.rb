# frozen_string_literal: true

class BasketMailer < ApplicationMailer
  include Templatable

  def initial_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "basket-initial",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def final_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "basket-final",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def first_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "basket-first",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def last_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "basket-last",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def second_last_trial_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "basket-second-last-trial",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def last_trial_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "basket-last-trial",
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end
end
