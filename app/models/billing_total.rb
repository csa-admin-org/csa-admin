class BillingTotal
  def self.all
    scopes = [BasketSize.all]
    scopes << :basket_complement if BasketComplement.any?
    scopes << :distribution if Distribution.paid.any?
    scopes << :halfday
    scopes << :annual_fee if Current.acp.annual_fee?
    scopes << :acp_share if Current.acp.share?
    scopes.flatten.map { |scope| new(scope) }
  end

  attr_reader :scope

  def initialize(scope)
    @memberships = Membership.joins(:member).where(members: { salary_basket: false }).current_year
    @scope = scope
  end

  def title
    case scope
    when BasketSize
      I18n.t('billing.scope.basket_size', name: scope.name)
    when :halfday
      I18n.t("billing.scope.#{scope}/#{Current.acp.halfday_i18n_scope}")
    else
      I18n.t("billing.scope.#{scope}")
    end
  end

  def price
    @price ||=
      case scope
      when BasketSize
        @memberships
          .joins(:baskets)
          .where(baskets: { basket_size_id: scope.id })
          .sum('baskets.quantity * baskets.basket_price')
      when :basket_complement
        @memberships
          .joins(baskets: :baskets_basket_complements)
          .sum('baskets_basket_complements.quantity * baskets_basket_complements.price')
      when :distribution
        @memberships
          .joins(:baskets)
          .sum('baskets.quantity * baskets.distribution_price')
      when :halfday
        @memberships.sum(:halfday_works_annual_price)
      when :annual_fee
        Invoice.current_year.not_canceled.sum(:annual_fee)
      when :acp_share
        Invoice.current_year.not_canceled.acp_share.sum(:amount)
      end
  end
end
