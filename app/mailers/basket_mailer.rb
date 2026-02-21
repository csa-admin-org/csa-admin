# frozen_string_literal: true

class BasketMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def initial_email = basket_email
  def final_email = basket_email
  def first_email = basket_email
  def last_email = basket_email
  def second_last_trial_email = basket_email
  def last_trial_email = basket_email

  private

  def set_context
    @basket = params[:basket]
    @membership = @basket.membership
    @member = @membership.member
  end

  def basket_email
    template_mail(@member,
      "basket" => Liquid::BasketDrop.new(@basket),
      "member" => Liquid::MemberDrop.new(@member),
      "membership" => Liquid::MembershipDrop.new(@membership))
  end
end
