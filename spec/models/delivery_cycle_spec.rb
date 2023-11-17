require 'rails_helper'

describe DeliveryCycle, freeze: '2022-01-01' do
  def member_ordered_names
    DeliveryCycle.member_ordered.map(&:name)
  end

  specify '#member_ordered' do
    Array(0..14).each do |i|
      create(:delivery, date: Date.today + i.days)
    end
    DeliveryCycle.delete_all
    a = create(:delivery_cycle, results: :all, wdays: [2,6], name: 'a')
    create(:delivery_cycle, results: :quarter_1, wdays: [1,5], name: 'b')
    create(:delivery_cycle, results: :odd, wdays: [3,4], name: 'c')

    expect(member_ordered_names).to eq %w[a c b]

    Current.acp.update! delivery_cycles_member_order_mode: 'deliveries_count_asc'
    expect(member_ordered_names).to eq %w[b c a]

    Current.acp.update! delivery_cycles_member_order_mode: 'name_asc'
    expect(member_ordered_names).to eq %w[a b c]

    Current.acp.update! delivery_cycles_member_order_mode: 'wdays_asc'
    expect(member_ordered_names).to eq %w[b a c]

    a.update! member_order_priority: 2
    expect(member_ordered_names).to eq %w[b c a]
  end

  specify 'only mondays' do
    Array(0..6).each do |i|
      create(:delivery, date: Date.today + i.days)
    end

    cycle = create(:delivery_cycle, wdays: [1])
    expect(cycle.current_deliveries_count).to eq 1
    expect(cycle.current_deliveries.first.date.wday).to eq 1
  end

  specify 'only Januray' do
    Array(0..11).each do |i|
      create(:delivery, date: Date.today + i.month)
    end

    cycle = create(:delivery_cycle, months: [2])
    expect(cycle.current_deliveries_count).to eq 1
    expect(cycle.current_deliveries.first.date.month).to eq 2
  end

  specify 'only odd weeks' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.week)
    end

    cycle = create(:delivery_cycle, week_numbers: :odd)
    expect(cycle.current_deliveries_count).to eq 5
    expect(cycle.current_deliveries.pluck(:date).map(&:cweek)).to eq [1, 3, 5, 7, 9]
  end

  specify 'only even weeks' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.week)
    end

    cycle = create(:delivery_cycle, week_numbers: :even)
    expect(cycle.current_deliveries_count).to eq 5
    expect(cycle.current_deliveries.pluck(:date).map(&:cweek)).to eq [52, 2, 4, 6, 8]
  end

  specify 'all but first results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, results: :all_but_first)
    expect(cycle.current_deliveries_count).to eq 9
    expect(cycle.current_deliveries.pluck(:number)).to eq (2..10).to_a
  end

  specify 'only odd results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, results: :odd)
    expect(cycle.current_deliveries_count).to eq 5
    expect(cycle.current_deliveries.pluck(:number)).to eq [1, 3, 5, 7, 9]
  end

  specify 'only even results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, results: :even)
    expect(cycle.current_deliveries_count).to eq 5
    expect(cycle.current_deliveries.pluck(:number)).to eq [2, 4, 6, 8, 10]
  end

  specify 'only first quarter results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, results: :quarter_1)
    expect(cycle.current_deliveries_count).to eq 3
    expect(cycle.current_deliveries.pluck(:number)).to eq [1, 5, 9]
  end

  specify 'only second quarter results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, results: :quarter_2)
    expect(cycle.current_deliveries_count).to eq 3
    expect(cycle.current_deliveries.pluck(:number)).to eq [2, 6, 10]
  end

  specify 'only third quarter results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, results: :quarter_3)
    expect(cycle.current_deliveries_count).to eq 2
    expect(cycle.current_deliveries.pluck(:number)).to eq [3, 7]
  end

  specify 'only fourth quarter results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, results: :quarter_4)
    expect(cycle.current_deliveries_count).to eq 2
    expect(cycle.current_deliveries.pluck(:number)).to eq [4, 8]
  end

  specify 'only first of each month results' do
    Array(0..11).each do |i|
      create(:delivery, date: Date.today.beginning_of_month + i.month )
      create(:delivery, date: Date.today.beginning_of_month + 2.days + i.month)
      create(:delivery, date: Date.today.beginning_of_month + 17.days + i.month)
    end

    cycle = create(:delivery_cycle, results: :first_of_each_month)
    expect(cycle.current_deliveries_count).to eq 12
    expect(cycle.current_deliveries.pluck(:number))
      .to eq [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34]
  end

  specify 'minimum 3 days gap' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle, minimum_gap_in_days: 3)
    expect(cycle.current_deliveries_count).to eq 4
    expect(cycle.current_deliveries.pluck(:number)).to eq [1, 4, 7, 10]

    cycle = create(:delivery_cycle, minimum_gap_in_days: 3, results: :all_but_first)
    expect(cycle.current_deliveries_count).to eq 3
    expect(cycle.current_deliveries.pluck(:number)).to eq [2, 5, 8]
  end

  specify 'only Tuesday, in Janury, odd weeks, and even results' do
    Array(0..60).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:delivery_cycle,
      wdays: [2],
      months: [1],
      week_numbers: :odd,
      results: :even)
    expect(cycle.current_deliveries_count).to eq 1
    expect(cycle.current_deliveries.first.date.wday).to eq 2
    expect(cycle.current_deliveries.first.date.cweek).to eq 3
    expect(cycle.current_deliveries.first.number).to eq 18
  end

  specify 'reset caches after update' do
    Array(0..2).each do |i|
      create(:delivery, date: Date.today + i.days)
    end
    Array(0..10).each do |i|
      create(:delivery, date: Date.today + 1.year + i.days)
    end

    cycle = create(:delivery_cycle, wdays: [0])

    expect { DeliveryCycle.find(cycle.id).update!(wdays: [0, 1]) }
      .to change { cycle.reload.deliveries_counts }
      .from('2022' => 1, '2023' => 2)
      .to('2022' => 2, '2023' => 4)

    expect(cycle.current_deliveries_count).to eq 2
    expect(cycle.future_deliveries_count).to eq 4
  end
end
