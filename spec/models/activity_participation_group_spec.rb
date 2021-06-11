require 'rails_helper'

describe ActivityParticipationGroup do
  let(:member) { create(:member) }

  it 'groups similar activity particiaptions together' do
    date = (3.days.from_now - 1.hour).to_date
    activity1 = create(:activity, date: date, start_time: '8:00', end_time: '9:00')
    activity2 = create(:activity, date: date, start_time: '9:00', end_time: '10:00')
    activity3 = create(:activity, date: date, start_time: '11:00', end_time: '12:00')
    activity4 = create(:activity, date: date, start_time: '12:00', end_time: '13:00')
    part1 = create(:activity_participation, member: member, activity: activity1, created_at: 2.months.ago)
    part2 = create(:activity_participation, member: member, activity: activity2, created_at: 2.months.ago)
    part3 = create(:activity_participation, member: member, activity: activity3, created_at: 2.months.ago)
    part4 = create(:activity_participation, member: member, activity: activity4, created_at: 2.months.ago)

    participations = ActivityParticipationGroup.group([part1, part2, part3, part4])
    group = ActivityParticipationGroup.new(participations.first)

    expect(group.activity.period).to eq '8:00-10:00, 11:00-13:00'
    expect(group.activity.date).to eq date
    expect(group.participants_count).to eq 1
    expect(group.member).to eq member
    expect(group.activity_id).to eq [activity1.id, activity4.id]
  end
end
