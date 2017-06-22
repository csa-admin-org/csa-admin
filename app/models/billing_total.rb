class BillingTotal
  SCOPES = %i[
    small_basket
    big_basket
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
      memberships =
        Membership.current_year.includes(:basket, :member, :distribution).to_a
      SCOPES.map { |scope| new(memberships, scope) }
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
    I18n.t("billing.scope.#{scope}")
  end

  def price
    @price ||=
      case scope
      when :small_basket
        @memberships.select { |m| m.basket.small? }.sum(&:basket_total_price)
      when :big_basket
        @memberships.select { |m| m.basket.big? }.sum(&:basket_total_price)
      when :distribution
        @memberships.sum(&:distribution_total_price)
      when :halfday_works
        @memberships.sum(&:halfday_works_total_price)
      when :support
        Member.billable.count(&:support_billable?) * Member::SUPPORT_PRICE
      end
  end
end
