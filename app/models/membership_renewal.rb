class MembershipRenewal
  MissingDeliveriesError = Class.new(StandardError)

  OPTIONAL_ATTRIBUTES = %w[
    baskets_annual_price_change
    basket_complements_annual_price_change
    activity_participations_demanded_annualy
    activity_participations_annual_price_change
    absences_included_annually
  ]

  attr_reader :membership, :fiscal_year

  def initialize(membership)
    @membership = membership
    @fiscal_year = Current.acp.fiscal_year_for(membership.fy_year + 1)
  end

  # This method only takes care of creating the new membership,
  # please use Membership#renew! directly.
  def renew!(attrs = {})
    unless Delivery.any_in_year?(@fiscal_year)
      raise MissingDeliveriesError, "Deliveries for the renewed fiscal year are missing."
    end
    new_membership = Membership.new(renewed_attrs(attrs))
    renew_complements(new_membership, attrs)
    if membership.basket_size_id != new_membership.basket_size_id
      new_membership.baskets_annual_price_change = nil
      new_membership.activity_participations_demanded_annualy = nil
      new_membership.activity_participations_annual_price_change = nil
    end
    if basket_complements_changed?(new_membership)
      new_membership.basket_complements_annual_price_change = nil
    end
    new_membership.save!
  end

  private

  def renewed_attrs(attrs = {})
    membership
      .attributes
      .slice(*(%w[
        member_id
        basket_size_id
        basket_quantity
        basket_price_extra
        depot_id
        delivery_cycle_id
      ] + (OPTIONAL_ATTRIBUTES & Current.acp.membership_renewed_attributes)))
      .symbolize_keys
      .merge(
        started_on: fiscal_year.beginning_of_year,
        ended_on: fiscal_year.end_of_year)
      .merge(
        attrs.slice(*%i[
          basket_size_id
          basket_price_extra
          depot_id
          delivery_cycle_id
        ]))
  end

  def renew_complements(new_membership, attrs)
    bc_attrs = []
    if attrs.key?(:memberships_basket_complements_attributes)
      attrs[:memberships_basket_complements_attributes].each { |i, attrs|
        bc_attrs << (membership_basket_complement_attrs(attrs) || attrs)
      }
    else
      membership.memberships_basket_complements.each do |mbc|
        bc_attrs << mbc.slice(*%w[quantity basket_complement_id])
      end
    end
    bc_attrs.each do |attrs|
      new_membership.memberships_basket_complements.build(attrs)
    end
  end

  def membership_basket_complement_attrs(attrs)
    membership
      .memberships_basket_complements
      .where(basket_complement_id: attrs[:basket_complement_id])
      .first
      &.attributes
      &.slice(*%w[
        quantity
        basket_complement_id
      ])
      &.symbolize_keys
      &.merge(attrs)
  end

  def basket_complements_changed?(new_membership)
    membership.memberships_basket_complements.pluck(:basket_complement_id).sort !=
      new_membership.memberships_basket_complements.map(&:basket_complement_id).sort
  end
end
