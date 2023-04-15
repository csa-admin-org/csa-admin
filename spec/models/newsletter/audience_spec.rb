require 'rails_helper'

describe Newsletter::Audience do
  specify 'encrypt and decrypt email' do
    email = 'thibaud@thibaud.gg'
    encrypted = described_class.encrypt_email(email)
    expect(described_class.decrypt_email(encrypted)).to eq email
  end

  specify 'decrypt email with invalid token' do
    expect(described_class.decrypt_email('invalid')).to be_nil
  end

  def segment_for(audience)
    described_class::Segment.parse(audience)
  end

  specify 'segment#name' do
    depot = create(:depot, id: 1, name: 'Depot')

    segment = segment_for('depot_id::1')
    expect(segment.name).to eq 'Depot'

    segment = segment_for('depot_id::2')
    expect(segment.name).to eq 'Inconnu'
  end

  specify 'member_state' do
    create(:member, :pending)
    waiting = create(:member, :waiting)
    active = create(:member, :active)
    support = create(:member, :support_annual_fee)
    inactive = create(:member, :inactive)

    segment = segment_for('member_state::all')
    expect(segment.members).to contain_exactly(waiting, active, support, inactive)

    segment = segment_for('member_state::not_inactive')
    expect(segment.members).to contain_exactly(waiting, active, support)

    segment = segment_for('member_state::waiting')
    expect(segment.members).to contain_exactly(waiting)

    segment = segment_for('member_state::active')
    expect(segment.members).to contain_exactly(active)

    segment = segment_for('member_state::support')
    expect(segment.members).to contain_exactly(support)

    segment = segment_for('member_state::inactive')
    expect(segment.members).to contain_exactly(inactive)
  end

  specify 'activity_state' do
    create(:membership, activity_participations_demanded_annualy: 0)
    demanded = create(:member)
    create(:membership, member: demanded, activity_participations_demanded_annualy: 1)
    create(:activity_participation, member: demanded)
    missing = create(:member)
    create(:membership, member: missing, activity_participations_demanded_annualy: 1)

    segment = segment_for('activity_state::demanded')
    expect(segment.members).to contain_exactly(demanded, missing)

    segment = segment_for('activity_state::missing')
    expect(segment.members).to contain_exactly(missing)
  end

  specify 'memberships' do
    create(:basket_size, id: 1)
    create(:basket_size, id: 2)
    create(:basket_complement, id: 1)
    create(:basket_complement, id: 2)
    create(:depot, id: 1)
    create(:depot, id: 2)

    member1 = create(:member)
    member2 = create(:member)
    member3 = create(:member)
    member4 = create(:member)
    create(:membership,
      member: member1,
      basket_size_id: 1,
      depot_id: 1)
    create(:membership,
      member: member2,
      basket_size_id: 1,
      depot_id: 2,
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, quantity: 1 }
      })
    create(:membership,
      member: member3,
      basket_size_id: 2,
      depot_id: 1,
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, quantity: 1 },
        '1' => { basket_complement_id: 2, quantity: 1 }
      })
    create(:membership,
      member: member4,
      basket_size_id: 2,
      depot_id: 2)

    segment = segment_for('basket_size_id::1')
    expect(segment.members).to contain_exactly(member1, member2)
    segment = segment_for('basket_size_id::2')
    expect(segment.members).to contain_exactly(member3, member4)

    segment = segment_for('basket_complement_id::1')
    expect(segment.members).to contain_exactly(member2, member3)
    segment = segment_for('basket_complement_id::2')
    expect(segment.members).to contain_exactly(member3)

    segment = segment_for('depot_id::1')
    expect(segment.members).to contain_exactly(member1, member3)
    segment = segment_for('depot_id::2')
    expect(segment.members).to contain_exactly(member2, member4)
  end

  specify 'delivery ignore absent or empty baskets' do
    member1 = create(:member)
    member2 = create(:member)
    member3 = create(:member)
    member4 = create(:member)
    create(:membership, member: member1)
    create(:membership, member: member2)
    create(:membership, member: member3)
    create(:membership, member: member4)

    delivery = Delivery.first

    member3.baskets.update_all(absent: true)
    member4.baskets.update_all(quantity: 0)

    segment = segment_for("delivery_id::#{delivery.gid}")
    expect(segment.members).to contain_exactly(member1, member2)
  end
end
