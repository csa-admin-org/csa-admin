# frozen_string_literal: true

class Liquid::DeliveryDrop < Liquid::Drop
  def initialize(delivery)
    @delivery = delivery
  end

  def date
    I18n.l(@delivery.date)
  end

  def date_iso
    @delivery.date.iso8601
  end

  def date_long
    I18n.l(@delivery.date, format: :long)
  end
end
