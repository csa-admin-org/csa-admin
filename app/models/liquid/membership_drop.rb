class Liquid::MembershipDrop < Liquid::Drop
  def initialize(membership)
    @membership = membership
  end

  def start_date
    I18n.l(@membership.started_on)
  end

  def end_date
    I18n.l(@membership.ended_on)
  end

  def first_delivery
    if delivery = @membership.deliveries.first
      Liquid::DeliveryDrop.new(delivery)
    end
  end

  def last_delivery
    if delivery = @membership.deliveries.last
      Liquid::DeliveryDrop.new(delivery)
    end
  end

  def trial_baskets_count
    @membership.remaning_trial_baskets_count
  end

  def activity_participations_demanded_count
    @membership.activity_participations_demanded
  end

  def basket_size
    Liquid::BasketSizeDrop.new(@membership.basket_size)
  end

  def basket_complements
    @membership.basket_complements.map do |bc|
      Liquid::BasketComplementDrop.new(bc)
    end
  end

  def basket_complement_names
    @membership.basket_complements.map(&:name).to_sentence(locale: I18n.locale).presence
  end

  def depot
    Liquid::DepotDrop.new(@membership.depot)
  end
end
