# frozen_string_literal: true

class Liquid::MemberCardDrop < Liquid::Drop
  def initialize(member_card)
    @member_card = member_card
  end

  def name
    @member_card.name
  end

  def number
    @member_card.masked_number
  end

  def expires_on
    return unless @member_card.expires_on

    I18n.l(@member_card.expires_on)
  end

  def card_name
    @member_card.price_reduction_card.name
  end
end
