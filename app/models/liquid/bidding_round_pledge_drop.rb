# frozen_string_literal: true

class Liquid::BiddingRoundPledgeDrop < Liquid::Drop
  include NumbersHelper

  private(*NumbersHelper.public_instance_methods)
  private(*ActiveSupport::NumberHelper.instance_methods)

  def initialize(pledge)
    @pledge = pledge
  end

  def basket_size_price
    @pledge && cur(@pledge.basket_size_price)
  end
end
