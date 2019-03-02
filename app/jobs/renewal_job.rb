class RenewalJob < ApplicationJob
  queue_as :default

  def perform(membership, year)
    fiscal_year = Current.acp.fiscal_year_for(year)
    renew!(membership, fiscal_year)
  end

  private

  def renew!(membership, fiscal_year)
    renewal = Membership.new(membership.attributes.slice(*%w[
      member_id
      basket_size_id
      basket_quantity
      baskets_annual_price_change
      depot_id
      seasons
      activity_participations_demanded_annualy
      activity_participations_annual_price_change
      basket_complements_annual_price_change
    ]).merge(
      started_on: fiscal_year.beginning_of_year,
      ended_on: fiscal_year.end_of_year
    ))
    membership.memberships_basket_complements.each do |mbc|
      renewal.memberships_basket_complements.build(mbc.attributes.slice(*%w[
        seasons
        quantity
        basket_complement_id
      ]))
    end
    renewal.save!
  end
end
