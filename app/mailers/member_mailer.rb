# frozen_string_literal: true

class MemberMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def activated_email
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "membership" => Liquid::MembershipDrop.new(@membership),
      "basket" => Liquid::BasketDrop.new(@basket))
  end

  def validated_email
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "waiting_list_position" => Member.waiting.count + 1,
      "waiting_basket_size_id" => @member.waiting_basket_size_id,
      "waiting_basket_size" => Liquid::BasketSizeDrop.new(@member.waiting_basket_size),
      "waiting_depot_id" => @member.waiting_depot_id,
      "waiting_depot" => Liquid::DepotDrop.new(@member.waiting_depot),
      "waiting_delivery_cycle_id" => @member.waiting_delivery_cycle_id,
      "waiting_delivery_cycle" => Liquid::DeliveryCycleDrop.new(@member.waiting_delivery_cycle))
  end

  private

  def set_context
    @member = params[:member]
    @membership = @member.current_or_future_membership
    @basket = @membership&.next_basket
  end
end
