class MemberMailerPreview < ActionMailer::Preview
  def activated_email
    params.merge!(activated_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :member_activated)
    MemberMailer.with(params).activated_email
  end

  private

  def random
    @random ||= Random.new(params[:random] || rand)
  end

  def activated_email_params
    {
      member: member,
      membership: membership
    }
  end

  def member
    OpenStruct.new(
      id: 1,
      name: ['Jane Doe', 'John Doe'].sample(random: random),
      language: params[:locale] || I18n.locale)
  end

  def membership
    basket_size = BasketSize.all.sample(random: random)
    OpenStruct.new(
      started_on: Date.today,
      ended_on: Current.fiscal_year.end_of_year,
      basket_size: basket_size,
      depot: Depot.visible.sample(random: random),
      remaning_trial_baskets_count: Current.acp.trial_basket_count,
      activity_participations_demanded: basket_size.activity_participations_demanded_annualy,
      basket_complements: BasketComplement.reorder(:id).sample(2, random: random))
  end
end


