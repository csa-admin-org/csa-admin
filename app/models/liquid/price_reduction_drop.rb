# frozen_string_literal: true

class Liquid::PriceReductionDrop < Liquid::Drop
  def initialize(price_reduction, amount: nil)
    @price_reduction = price_reduction
    @amount = amount
  end

  def id
    @price_reduction.id
  end

  def name
    @price_reduction.public_name
  end

  def amount
    return if @amount.nil?

    ApplicationController.helpers.cur(@amount)
  end
end
