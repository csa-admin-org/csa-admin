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
    create(:delivery, date: next_fy.beginning_of_year)
    membership = create(:membership,
      basket_quantity: 2,
      basket_price: 42,
      basket_price_extra: 1,
      baskets_annual_price_change: 130,
      depot_price: 3,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60)

    membership.basket_size.update!(price: 41)
    membership.depot.update!(price: 4)

    expect {
      MembershipRenewal.new(membership).renew!(
        renewal_note: 'Je suis content')
    }.to change(Membership, :count).by(1)

    expect(membership.renewed_membership).to have_attributes(
      member_id: membership.member_id,
      basket_size_id: membership.basket_size_id,
      basket_quantity: 2,
      basket_price: 41,
      basket_price_extra: 1,
      baskets_annual_price_change: 130,
      depot_id: membership.depot_id,
      depot_price: 4,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60,
      started_on: next_fy.beginning_of_year,
      ended_on: next_fy.end_of_year)
  end

  it 'resets annual settings if basket size change' do
    create(:delivery, date: next_fy.beginning_of_year)
    membership = create(:membership,
      basket_quantity: 2,
      basket_price: 22,
      basket_price_extra: 1,
      baskets_annual_price_change: 130,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60)

    big = create(:basket_size, :big,
      price: 33,
      activity_participations_demanded_annualy: 6)

    expect {
      MembershipRenewal.new(membership).renew!(basket_size_id: big.id)
    }.to change(Membership, :count).by(1)

    expect(membership.renewed_membership).to have_attributes(
      member_id: membership.member_id,
      basket_size_id: big.id,
      basket_quantity: 2,
      basket_price: 33,
      basket_price_extra: 1,
      baskets_annual_price_change: 0,
      activity_participations_demanded_annualy: 12,
      activity_participations_annual_price_change: 0,
      started_on: next_fy.beginning_of_year,
      ended_on: next_fy.end_of_year)
  end

  it 'renews a membership with basket_price_extra' do
    create(:delivery, date: next_fy.beginning_of_year)
    membership = create(:membership,
      basket_quantity: 2,
      basket_price: 42,
      basket_price_extra: 1,
      baskets_annual_price_change: 130,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60)
    big = create(:basket_size, :big)

    expect {
      MembershipRenewal.new(membership).renew!(
        basket_price_extra: 4,
        renewal_note: 'Je suis super content')
    }.to change(Membership, :count).by(1)

    expect(membership.renewed_membership).to have_attributes(
      basket_price_extra: 4,
      basket_quantity: 2,
      baskets_annual_price_change: 130,
      depot_id: membership.depot_id,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60,
      started_on: next_fy.beginning_of_year,
      ended_on: next_fy.end_of_year)
  end

  it 'renews a membership with a new depot and deliveries cycle' do
    create(:delivery, date: next_fy.beginning_of_year)
    membership = create(:membership)
    new_deliveries_cycle = create(:deliveries_cycle)
    new_depot = create(:depot, deliveries_cycles: [new_deliveries_cycle])

    expect {
      MembershipRenewal.new(membership).renew!(
        depot_id: new_depot.id,
        deliveries_cycle_id: new_deliveries_cycle.id,
        renewal_note: 'Je suis super content')
    }.to change(Membership, :count).by(1)

    expect(membership.renewed_membership).to have_attributes(
      depot_id: new_depot.id,
      deliveries_cycle_id: new_deliveries_cycle.id)
  end

  it 'resets basket_complements_annual_price_change when complements changes' do
    create(:delivery, date: next_fy.beginning_of_year)
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)
    membership = create(:membership,
      basket_complements_annual_price_change: -32,
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: 3, quantity: 1 },
        '1' => { basket_complement_id: 2, price: 5, quantity: 2 }
      })

    expect {
      MembershipRenewal.new(membership).renew!(
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 1 },
        }
      )
    }.to change(Membership, :count).by(1)

    renewed = membership.renewed_membership
    expect(renewed).to have_attributes(
      basket_complements_annual_price_change: 0)
    expect(renewed.memberships_basket_complements.count).to eq 1
  end

  specify 'ignore optional attributes' do
    create(:delivery, date: next_fy.beginning_of_year)
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)
    membership = create(:membership,
      baskets_annual_price_change: 130,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: -60,
      basket_complements_annual_price_change: -32,
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, quantity: 1 }
      })

    Current.acp.update!(membership_renewed_attributes: %w[
      activity_participations_demanded_annualy
    ])

    expect {
      MembershipRenewal.new(membership).renew!(
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 1 },
        }
      )
    }.to change(Membership, :count).by(1)

    expect(membership.renewed_membership).to have_attributes(
      baskets_annual_price_change: 0,
      activity_participations_demanded_annualy: 5,
      activity_participations_annual_price_change: 0,
      basket_complements_annual_price_change: 0)
  end
end
