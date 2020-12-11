class MembershipRenewal
  MissingDeliveriesError = Class.new(StandardError)

  attr_reader :membership, :fiscal_year

  def initialize(membership)
    @membership = membership
    @fiscal_year = Current.acp.fiscal_year_for(membership.fy_year + 1)
  end

  # This method only takes care of creating the new membership,
  # please use Membership#renew! directly.
  def renew!(attrs = {})
    unless Delivery.any_next_year?
      raise MissingDeliveriesError, 'Deliveries for next fiscal year are missing.'
    end
    new_membership = Membership.new(renewed_attrs(attrs))
    if BasketComplement.any?
      renew_complements(new_membership, attrs)
    end
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
      .slice(*%w[
        member_id
        basket_size_id
        basket_quantity
        baskets_annual_price_change
        depot_id
        seasons
        activity_participations_demanded_annualy
        activity_participations_annual_price_change
        basket_complements_annual_price_change
      ])
      .merge(
        started_on: fiscal_year.beginning_of_year,
        ended_on: fiscal_year.end_of_year)
      .merge(
        attrs
          .stringify_keys
          .slice(*%w[basket_size_id basket_price_extra depot_id]))
  end

  def renew_complements(new_membership, attrs)
    bc_ids =
      attrs[:basket_complement_ids]&.map(&:presence)&.compact ||
        membership.memberships_basket_complements.pluck(:basket_complement_id)
    bc_ids.each do |bc_id|
      bc_attrs =
        membership_basket_complement_attrs(bc_id) ||
          { basket_complement_id: bc_id }
      new_membership.memberships_basket_complements.build(bc_attrs)
    end
  end

  def membership_basket_complement_attrs(bc_id)
    membership
      .memberships_basket_complements
      .where(basket_complement_id: bc_id)
      .first
      &.attributes
      &.slice(*%w[
        seasons
        quantity
        basket_complement_id
      ])
  end

  def basket_complements_changed?(new_membership)
    membership.memberships_basket_complements.pluck(:basket_complement_id).sort !=
      new_membership.memberships_basket_complements.map(&:basket_complement_id).sort
  end
end
