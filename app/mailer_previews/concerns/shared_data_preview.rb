module SharedDataPreview
  extend ActiveSupport::Concern

  private

  def random
    @random ||= Random.new(params[:random] || rand)
  end

  def member
    OpenStruct.new(
      id: 1,
      name: ['Jane Doe', 'John Doe'].sample(random: random),
      language: params[:locale] || I18n.locale,
      current_or_future_membership: membership,
      waiting_basket_size_id: basket_size&.id,
      waiting_depot_id: depot&.id,
      activity_participations: ActivityParticipation.coming.limit(1))
  end

  def membership
    return unless basket

    participations_demanded = basket_size&.activity_participations_demanded_annualy || 0
    participations_accepted = [participations_demanded, 0].sample(random: random)
    OpenStruct.new(
      started_on: started_on,
      ended_on: ended_on,
      basket_size: basket_size,
      deliveries: deliveries,
      depot: depot,
      next_basket: basket,
      basket_quantity: 1,
      remaning_trial_baskets_count: Current.acp.trial_basket_count,
      activity_participations_demanded: participations_demanded,
      activity_participations_accepted: participations_accepted,
      missing_activity_participations: participations_demanded - participations_accepted,
      memberships_basket_complements: memberships_basket_complements)
  end

  def started_on
    Current.fiscal_year.beginning_of_year
  end

  def ended_on
    Current.fiscal_year.end_of_year
  end

  def deliveries
    Delivery.between(started_on..ended_on)
  end

  def basket
    return unless delivery = (deliveries.next || deliveries.last)

    delivery.baskets.where(quantity: 1..).sample(random: random)
  end

  def basket_size
    basket&.basket_size
  end

  def depot
    basket&.depot
  end

  def memberships_basket_complements
    BasketComplement
      .reorder(:id)
      .sample(2, random: random)
      .map { |bc|
        OpenStruct.new(
          quantity: 1,
          basket_complement: bc)
      }
  end
end
