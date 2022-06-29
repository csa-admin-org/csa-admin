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
      waiting_depot_id: depot&.id)
  end

  def membership
    started_on = Current.fiscal_year.beginning_of_year
    ended_on = Current.fiscal_year.end_of_year
    OpenStruct.new(
      started_on: started_on,
      ended_on: ended_on,
      basket_size: basket_size,
      deliveries: Delivery.between(started_on..ended_on),
      depot: depot,
      remaning_trial_baskets_count: Current.acp.trial_basket_count,
      activity_participations_demanded: basket_size&.activity_participations_demanded_annualy,
      basket_complements: BasketComplement.reorder(:id).sample(2, random: random))
  end

  def basket_size
    BasketSize.all.sample(random: random)
  end

  def depot
    Depot.visible.sample(random: random)
  end
end
