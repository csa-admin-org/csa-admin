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
      current_or_future_membership: membership)
  end

  def membership
    basket_size = BasketSize.all.sample(random: random)
    started_on = Date.today
    ended_on = Current.fiscal_year.end_of_year
    OpenStruct.new(
      started_on: started_on,
      ended_on: ended_on,
      basket_size: basket_size,
      deliveries: Delivery.between(started_on..ended_on),
      depot: Depot.visible.sample(random: random),
      remaning_trial_baskets_count: Current.acp.trial_basket_count,
      activity_participations_demanded: basket_size&.activity_participations_demanded_annualy,
      basket_complements: BasketComplement.reorder(:id).sample(2, random: random))
  end
end
