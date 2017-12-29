class BillingTotal
  SCOPES = %i[distribution halfday_works support]

  def self.all
    scopes = [BasketSize.all + SCOPES]
    scopes.flatten.map { |scope| new(scope) }
  end

  attr_reader :scope

  def initialize(scope)
    @memberships = Membership.joins(:member).where(members: { salary_basket: false }).current_year
    @scope = scope
    # eager load for the cache
    price
  end

  def title
    if scope.is_a?(BasketSize)
      I18n.t("billing.scope.basket_size", name: scope.name)
    else
      I18n.t("billing.scope.#{scope}")
    end
  end

  def price
    @price ||=
      case scope
      when BasketSize
        @memberships.joins(:baskets).where(baskets: { basket_size_id: scope.id }).sum(:basket_price)
      when :distribution
        @memberships.joins(:baskets).sum(:distribution_price)
      when :halfday_works
        @memberships.sum(:halfday_works_annual_price)
      when :support
        Invoice.current_year.sum(:support_amount)
      end
  end
end
