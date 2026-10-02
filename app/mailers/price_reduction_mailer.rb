# frozen_string_literal: true

class PriceReductionMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def card_expiring_email
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "member_card" => Liquid::MemberCardDrop.new(@member_card))
  end

  private

  def set_context
    @member = params[:member]
    @member_card = params[:member_card]
  end
end
