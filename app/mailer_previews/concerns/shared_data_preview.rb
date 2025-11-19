# frozen_string_literal: true

require "ostruct"

module SharedDataPreview
  extend ActiveSupport::Concern

  private

  def random
    @random ||= Random.new(params[:random] || rand)
  end

  def member
    OpenStruct.new(
      id: 1,
      name: [ "Jane Doe", "John Doe" ].sample(random: random),
      language: params[:locale] || I18n.locale,
      annual_fee: Current.org.annual_fee,
      current_or_future_membership: membership,
      waiting_basket_size_id: basket_size&.id,
      waiting_basket_size: basket_size,
      waiting_depot_id: depot&.id,
      waiting_depot: depot,
      waiting_delivery_cycle_id: delivery_cycle.id,
      waiting_delivery_cycle: delivery_cycle,
      activity_participations: ActivityParticipation.coming.limit(1))
  end

  def membership
    return unless basket

    participations_demanded = basket_size&.activity_participations_demanded_annually || 0
    participations_accepted = [ participations_demanded, 0 ].sample(random: random)
    OpenStruct.new(
      started_on: started_on,
      ended_on: ended_on,
      state: "ongoing",
      renewal_state: "renewal_pending",
      basket_size: basket_size,
      deliveries: deliveries,
      depot: depot,
      delivery_cycle: delivery_cycle,
      absences_included: delivery_cycle.absences_included_annually,
      next_basket: basket,
      basket_quantity: 1,
      remaining_trial_baskets_count: Current.org.trial_baskets_count,
      activity_participations_demanded: participations_demanded,
      activity_participations_accepted: participations_accepted,
      activity_participations_missing: [ participations_demanded - participations_accepted, 0 ].max,
      memberships_basket_complements: memberships_basket_complements)
  end

  def started_on
    fiscal_year.beginning_of_year
  end

  def ended_on
    fiscal_year.end_of_year
  end

  def deliveries
    @deliveries ||=
      if delivery_cycle.current_deliveries_count.positive?
        Delivery.where(id: delivery_cycle.current_deliveries.map(&:id))
      else
        Delivery.where(id: delivery_cycle.future_deliveries.map(&:id))
      end
  end

  def basket
    return unless delivery

    delivery.baskets.where(quantity: 1..).sample(random: random)
  end

  def basket_size
    @basket_size ||= basket&.basket_size || BasketSize.visible.sample(random: random)
  end

  def depot
    @depot ||= basket&.depot || Depot.visible.sample(random: random)
  end

  def delivery
    @delivery ||= Delivery.next || Delivery.last
  end

  def delivery_cycle
    @delivery_cycle ||=
     if delivery
       DeliveryCycle.for(delivery).max_by(&:billable_deliveries_count)
     else
       DeliveryCycle.primary
     end
  end

  def memberships_basket_complements
    BasketComplement
      .reorder(:id)
      .sample(2, random: random)
      .map { |bc|
        MembershipsBasketComplement.new(
          quantity: 1,
          basket_complement: bc)
      }
  end

  def fiscal_year
    @fiscal_year ||= delivery&.fiscal_year || Current.fiscal_year
  end
end
