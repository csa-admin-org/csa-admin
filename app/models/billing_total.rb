class BillingTotal
  SCOPES = %i[
    distribution
    halfday_works
    support
  ]

  def self.all
    cache_key = [
      name,
      Member.maximum(:updated_at),
      Membership.maximum(:updated_at)
    ]
    Rails.cache.fetch cache_key do
      memberships = Membership.current_year.to_a
      [BasketSize.all + SCOPES].flatten.map { |scope| new(memberships, scope) }
    end
  end

  attr_reader :scope

  def initialize(memberships, scope)
    @memberships = memberships
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
        @memberships.sum { |m| m.baskets_price(scope.id) }
      when :distribution
        @memberships.sum { |m| m.distribution_total_price }
      when :halfday_works
        @memberships.sum(&:halfday_works_total_price)
      when :support
        Member.billable.count(&:support_billable?) * Member::SUPPORT_PRICE
      end
  end
end
