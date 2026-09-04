# frozen_string_literal: true

class Liquid::AdminBasketDrop < Liquid::Drop
  def initialize(basket, overlay: nil)
    @basket = basket
    @overlay = overlay
  end

  def member
    Liquid::MemberDrop.new(@basket.member)
  end

  def description
    @basket.description
  end

  def temporary_address
    @overlay.present?
  end
end
