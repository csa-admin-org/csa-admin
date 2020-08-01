require 'rails_helper'

describe MembershipRenewal do
  let(:next_fy) { Current.acp.fiscal_year_for(Date.today.year + 1) }

  it 'raises when no next year deliveries' do
    membership = create(:membership)

    expect(Delivery.between(next_fy.range).count).to be_zero
    expect { MembershipRenewal.new(membership).renew! }
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
    big = create(:basket_size, :big)

    membership.basket_size.update!(price: 41)
    membership.depot.update!(price: 4)

    expect {
      MembershipRenewal.new(membership).renew!(
        basket_size_id: big.id,
        renewal_note: 'Je suis content')
    }.to change(Membership, :count).by(1)

    expect(membership.renewed_membership).to have_attributes(
      member_id: membership.member_id,
      basket_size_id: big.id,
      basket_price: big.price,
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
        '0' => { basket_complement_id: 1, price: 3, seasons: %w[winter], quantity: 1 },
        '1' => { basket_complement_id: 2, price: 5, quantity: 2 }
      })

    expect { MembershipRenewal.new(membership).renew!(basket_complement_ids: ['', '1']) }
      .to change(Membership, :count).by(1)

      renewed = membership.renewed_membership
    expect(renewed).to have_attributes(
      seasons: %w[summer])
      expect(renewed.memberships_basket_complements.count).to eq 1
    expect(renewed.memberships_basket_complements.first).to have_attributes(
      seasons: %w[winter],
      basket_complement_id: 1,
      price: 3.2,
      quantity: 1)
  end
end
