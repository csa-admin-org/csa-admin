# frozen_string_literal: true

class BasketMailer < ApplicationMailer
  include Templatable

  def initial_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def final_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def first_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def last_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def second_last_trial_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end

  def last_trial_email
    basket = params[:basket]
    membership = params[:membership] || basket&.membership
    member = params[:member] || membership&.member
    template_mail(member,
      "basket" => Liquid::BasketDrop.new(basket),
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end
end
