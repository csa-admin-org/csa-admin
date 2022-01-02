require 'rails_helper'

describe MembershipRenewalJob do
  let(:next_fy) { Current.acp.fiscal_year_for(Date.today.year + 1) }

  it 'raises when no next year deliveries' do
    membership = create(:membership)

    expect(Delivery.between(next_fy.range).count).to be_zero
    expect { MembershipRenewalJob.perform_now(membership) }
      .to raise_error(MembershipRenewal::MissingDeliveriesError)
  end

  it 'renews a membership without complements' do
    Delivery.create_all(1, next_fy.beginning_of_year)
    membership = create(:membership,
      basket_quantity: 2,
      basket_price: 42,
      baskets_annual_price_change: 130,
      depot_price: 3,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60)

    membership.basket_size.update!(price: 41)
    membership.depot.update!(price: 4)

    expect { MembershipRenewalJob.perform_now(membership) }
      .to change(Membership, :count).by(1)

    expect(Membership.last).to have_attributes(
      member_id: membership.member_id,
      basket_size_id: membership.basket_size_id,
      basket_price: 41,
      basket_quantity: 2,
      baskets_annual_price_change: 130,
      depot_id: membership.depot_id,
      depot_price: 4,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60,
      started_on: next_fy.beginning_of_year,
      ended_on: next_fy.end_of_year)
  end

  it 'renews a membership with complements and seasons' do
    Delivery.create_all(1, next_fy.beginning_of_year)
    Current.acp.update!(
      summer_month_range_min: 4,
      summer_month_range_max: 9)
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)
    membership = create(:membership,
      seasons: %w[summer],
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: 3, quantity: 1 },
        '1' => { basket_complement_id: 2, price: 5, quantity: 2 }
      })

    expect { MembershipRenewalJob.perform_now(membership) }
      .to change(Membership, :count).by(1)

    renewal = Membership.last
    expect(renewal).to have_attributes(
      seasons: %w[summer])
    expect(renewal.memberships_basket_complements.first).to have_attributes(
      basket_complement_id: 1,
      price: 3.2,
      quantity: 1)
    expect(renewal.memberships_basket_complements.last).to have_attributes(
      basket_complement_id: 2,
      price: 4.5,
      quantity: 2)
  end
end
