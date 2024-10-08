# frozen_string_literal: true

require "rails_helper"

describe Newsletter::Segment do
  let(:template) { create(:newsletter_template) }

  specify "segment by basket_size" do
    basket_size_1 = create(:basket_size, id: 1)
    basket_size_2 = create(:basket_size, id: 2)
    member_1 = create(:membership, basket_size: basket_size_1).member
    member_2 = create(:membership, basket_size: basket_size_2).member

    segment = create(:newsletter_segment, basket_size_ids: [ 1 ])
    expect(segment.members).to contain_exactly(member_1)

    segment = create(:newsletter_segment, basket_size_ids: [])
    expect(segment.members).to contain_exactly(member_1, member_2)

    segment = create(:newsletter_segment, basket_size_ids: [ 1, 2 ])
    expect(segment.members).to contain_exactly(member_1, member_2)
  end

  specify "segment by basket_complement" do
    basket_complement_1 = create(:basket_complement, id: 1)
    basket_complement_2 = create(:basket_complement, id: 2)
    member_1 = create(:membership, memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 1, price: "", quantity: 1 }
      }).member
    member_2 = create(:membership, memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 2, price: "", quantity: 1 }
      }).member

    segment = create(:newsletter_segment, basket_complement_ids: [ 1 ])
    expect(segment.members).to contain_exactly(member_1)

    segment = create(:newsletter_segment, basket_complement_ids: [])
    expect(segment.members).to contain_exactly(member_1, member_2)

    segment = create(:newsletter_segment, basket_complement_ids: [ 1, 2 ])
    expect(segment.members).to contain_exactly(member_1, member_2)
  end

  specify "segment by depot" do
    depot_1 = create(:depot, id: 1)
    depot_2 = create(:depot, id: 2)
    member_1 = create(:membership, depot: depot_1).member
    member_2 = create(:membership, depot: depot_2).member

    segment = create(:newsletter_segment, depot_ids: [ 1 ])
    expect(segment.members).to contain_exactly(member_1)

    segment = create(:newsletter_segment, depot_ids: [])
    expect(segment.members).to contain_exactly(member_1, member_2)

    segment = create(:newsletter_segment, depot_ids: [ 1, 2 ])
    expect(segment.members).to contain_exactly(member_1, member_2)
  end

  specify "segment by deliveries cycle" do
    create(:basket_size)
    cycle_1 = create(:delivery_cycle)
    depot_1 = create(:depot, delivery_cycles: [ cycle_1 ])
    cycle_2 = create(:delivery_cycle)
    depot_2 = create(:depot, delivery_cycles: [ cycle_2 ])
    member_1 = create(:membership, depot: depot_1).member
    member_2 = create(:membership, depot: depot_2).member

    segment = create(:newsletter_segment, delivery_cycle_ids: [ cycle_1.id ])
    expect(segment.members).to contain_exactly(member_1)

    segment = create(:newsletter_segment, delivery_cycle_ids: [])
    expect(segment.members).to contain_exactly(member_1, member_2)

    segment = create(:newsletter_segment, delivery_cycle_ids: [ cycle_1.id, cycle_2.id ])
    expect(segment.members).to contain_exactly(member_1, member_2)
  end

  specify "segment by coming deliveries in days", freeze: "2023-01-01" do
    create(:basket_size)
    create(:delivery, date: "2023-01-07")
    create(:delivery, date: "2023-01-14")
    create(:delivery, date: "2023-01-21")
    cycle_1 = create(:delivery_cycle)
    depot_1 = create(:depot, delivery_cycles: [ cycle_1 ])
    cycle_2 = create(:delivery_cycle, results: :even)
    depot_2 = create(:depot, delivery_cycles: [ cycle_2 ])
    member_1 = create(:membership, depot: depot_1).member
    member_2 = create(:membership, depot: depot_2).member

    expect(member_1.next_basket.delivery.date.to_s).to eq "2023-01-07"
    expect(member_2.next_basket.delivery.date.to_s).to eq "2023-01-14"

    segment = create(:newsletter_segment, coming_deliveries_in_days: 10)
    expect(segment.members).to contain_exactly(member_1)
  end

  specify "segment by renewal state" do
    member_1 = create(:membership).member
    member_2 = create(:membership).member

    member_1.membership.update!(renew: false)
    member_2.membership.update!(renewal_opened_at: Time.current)

    segment = create(:newsletter_segment, renewal_state: "renewal_canceled")
    expect(segment.members).to contain_exactly(member_1)

    segment = create(:newsletter_segment, renewal_state: "renewal_opened")
    expect(segment.members).to contain_exactly(member_2)

    segment = create(:newsletter_segment, renewal_state: nil)
    expect(segment.members).to contain_exactly(member_1, member_2)
  end

  specify "segment by first_membership" do
    member_1 = create(:membership, :last_year).member
    create(:membership, member: member_1)
    member_2 = create(:membership).member

    segment = create(:newsletter_segment, first_membership: false)
    expect(segment.members).to contain_exactly(member_1)

    segment = create(:newsletter_segment, first_membership: true)
    expect(segment.members).to contain_exactly(member_2)

    segment = create(:newsletter_segment, first_membership: nil)
    expect(segment.members).to contain_exactly(member_1, member_2)
  end

  specify "segment by billing_year_division" do
    Current.org.update!(billing_year_divisions: [ 1, 4 ])
    member_1 = create(:membership, billing_year_division: 1).member
    member_2 = create(:membership, billing_year_division: 4).member

    segment = create(:newsletter_segment, billing_year_division: 1)
    expect(segment.members).to contain_exactly(member_1)

    segment = create(:newsletter_segment, billing_year_division: 4)
    expect(segment.members).to contain_exactly(member_2)

    segment = create(:newsletter_segment, billing_year_division: nil)
    expect(segment.members).to contain_exactly(member_1, member_2)
  end
end
