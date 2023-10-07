require 'rails_helper'

describe MembershipBasketsUpdater do
  let(:cycle) { create(:deliveries_cycle) }
  let(:depot) { create(:depot, deliveries_cycles: [cycle]) }
  let(:membership) {
    create(:delivery, date: '2022-01-05') # Wednesday
    create(:delivery, date: '2022-01-06') # Thursday
    create(:delivery, date: '2022-01-12') # Wednesday
    create(:delivery, date: '2022-01-13') # Thursday
    create(:delivery, date: '2022-01-19') # Wednesday
    create(:delivery, date: '2022-01-20') # Thursday
    create(:membership,
      depot: depot,
      started_on: '2022-01-01',
      ended_on: '2022-01-31')
  }

  specify 'update membership cycle when removed from depot but not when added', freeze: '2022-01-01' do
    membership
    other_cycle = create(:deliveries_cycle, wdays: [3])
    expect(other_cycle.current_deliveries_count).to eq(3)
    other_depot = create(:depot, deliveries_cycles: [other_cycle])
    other_membership = create(:membership,
      depot: other_depot,
      deliveries_cycle: other_cycle,
      started_on: '2022-01-01',
      ended_on: '2022-01-31')

    # Update other membership to ensure it is not updated when depot is updated
    other_membership.update!(updated_at: '2022-01-02')

    expect { depot.update!(deliveries_cycles: [cycle, other_cycle]) }
      .not_to change { other_membership.reload.updated_at }

    expect { depot.update!(deliveries_cycles: [other_cycle]) }
      .to change { membership.reload.baskets.count }.from(6).to(3)
      .and change { membership.reload.price }.from(180).to(90)
      .and change { membership.reload.deliveries_cycle }.from(cycle).to(other_cycle)

    expect(membership.deliveries.map(&:date).map(&:to_s)).to eq([
      '2022-01-05',
      '2022-01-12',
      '2022-01-19'
    ])

    expect { depot.update!(deliveries_cycles: [cycle]) }
      .to change { membership.reload.baskets.count }.from(3).to(6)
  end

  specify 'update membership when cycle updated', freeze: '2022-01-01' do
    expect { cycle.update!(wdays: [3]) }
      .to change { membership.reload.baskets.count }.from(6).to(3)
      .and change { membership.reload.price }.from(180).to(90)

    expect(membership.deliveries.map(&:date).map(&:to_s)).to eq([
      '2022-01-05',
      '2022-01-12',
      '2022-01-19'
    ])

    expect { cycle.update!(wdays: [4]) }
      .not_to change { membership.reload.baskets.count }.from(3)

    expect(membership.deliveries.map(&:date).map(&:to_s)).to eq([
      '2022-01-06',
      '2022-01-13',
      '2022-01-20'
    ])

    expect { cycle.update!(wdays: [3, 4]) }
      .to change { membership.reload.baskets.count }.from(3).to(6)
  end

  specify 'only change future baskets' do
    travel_to('2022-01-01') { membership }
    travel_to '2022-01-07' do
      expect { cycle.update!(wdays: [3]) }
        .to change { membership.reload.baskets.count }.from(6).to(4)
    end
    expect(membership.deliveries.map(&:date).map(&:to_s)).to eq([
      '2022-01-05',
      '2022-01-06',
      '2022-01-12',
      '2022-01-19'
    ])
  end

  specify 'leave untouched past baskets of ended membership' do
    travel_to('2022-01-01') do
      membership
      membership.update!(ended_on: '2022-01-15')
    end
    travel_to '2022-01-16' do
      delivery = Delivery.find_by(date: '2022-01-19')

      expect { delivery.update!(date: '2022-02-02') }
        .not_to change { membership.reload.baskets.count }.from(4)
    end
  end

  specify 'update when delivery is created', freeze: '2022-01-01' do
    membership

    expect { create(:delivery, date: '2022-01-31') }
      .to change { membership.reload.baskets.count }.from(6).to(7)
      .and change { membership.reload.price }.from(180).to(210)

    expect(membership.deliveries.map(&:date).map(&:to_s)).to eq([
      '2022-01-05',
      '2022-01-06',
      '2022-01-12',
      '2022-01-13',
      '2022-01-19',
      '2022-01-20',
      '2022-01-31'
    ])
  end

  specify 'update when delivery date is changing', freeze: '2022-01-01' do
    membership
    delivery = Delivery.find_by(date: '2022-01-12')

    expect { delivery.update!(date: '2022-02-02') }
      .to change { membership.reload.baskets.count }.from(6).to(5)
      .and change { membership.reload.price }.from(180).to(150)

    expect(membership.deliveries.map(&:date).map(&:to_s)).to eq([
      '2022-01-05',
      '2022-01-06',
      '2022-01-13',
      '2022-01-19',
      '2022-01-20'
    ])
  end

  specify 'update when delivery date is destroyed', freeze: '2022-01-01' do
    membership
    delivery = Delivery.find_by(date: '2022-01-12')

    expect { delivery.destroy! }
      .to change { membership.reload.baskets.count }.from(6).to(5)
      .and change { membership.reload.price }.from(180).to(150)

    expect(membership.deliveries.map(&:date).map(&:to_s)).to eq([
      '2022-01-05',
      '2022-01-06',
      '2022-01-13',
      '2022-01-19',
      '2022-01-20'
    ])
  end
end
