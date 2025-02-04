# frozen_string_literal: true

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

  def state
    @membership.state
  end

  def renewal_state
    @membership.renewal_state
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
    @membership.remaining_trial_baskets_count
  end

  def activity_participations_demanded_count
    return unless Current.org.feature?("activity")

    @membership.activity_participations_demanded
  end

  def activity_participations_accepted_count
    return unless Current.org.feature?("activity")

    @membership.activity_participations_accepted
  end

  def activity_participations_missing_count
    return unless Current.org.feature?("activity")

    @membership.activity_participations_missing
  end

  def basket_size
    Liquid::BasketSizeDrop.new(@membership.basket_size)
  end

  def basket_quantity
    @membership.basket_quantity
  end

  def basket_complements
    @membership.memberships_basket_complements.map do |mbc|
      Liquid::BasketComplementDrop.new(mbc)
    end
  end

  def basket_complement_names
    @membership
      .memberships_basket_complements
      .map(&:basket_complement)
      .map(&:name)
      .sort
      .to_sentence(locale: I18n.locale)
      .presence
  end

  def basket_complements_description
    helpers.basket_complements_description(@membership.memberships_basket_complements, text_only: true)
  end

  def depot
    Liquid::DepotDrop.new(@membership.depot)
  end

  def delivery_cycle
    Liquid::DeliveryCycleDrop.new(@membership.delivery_cycle)
  end

  def absences_included
    @membership.absences_included
  end

  private

  def helpers
    ApplicationController.helpers
  end
end
