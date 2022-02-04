require 'rails_helper'

describe DeliveriesCycle, freeze: '2022-01-01' do
  specify 'only mondays' do
    Array(0..6).each do |i|
      create(:delivery, date: Date.today + i.days)
    end

    cycle = create(:deliveries_cycle, wdays: [1])
    expect(cycle.current_deliveries.count).to eq 1
    expect(cycle.current_deliveries.first.date.wday).to eq 1
  end

  specify 'only Januray' do
    Array(0..11).each do |i|
      create(:delivery, date: Date.today + i.month)
    end

    cycle = create(:deliveries_cycle, months: [2])
    expect(cycle.current_deliveries.count).to eq 1
    expect(cycle.current_deliveries.first.date.month).to eq 2
  end

  specify 'only odd weeks' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.week)
    end

    cycle = create(:deliveries_cycle, week_numbers: :odd)
    expect(cycle.current_deliveries.count).to eq 5
    expect(cycle.current_deliveries.pluck(:date).map(&:cweek)).to eq [1, 3, 5, 7, 9]
  end

  specify 'only even weeks' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.week)
    end

    cycle = create(:deliveries_cycle, week_numbers: :even)
    expect(cycle.current_deliveries.count).to eq 5
    expect(cycle.current_deliveries.pluck(:date).map(&:cweek)).to eq [52, 2, 4, 6, 8]
  end

  specify 'only odd results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:deliveries_cycle, results: :odd)
    expect(cycle.current_deliveries.count).to eq 5
    expect(cycle.current_deliveries.pluck(:number)).to eq [1, 3, 5, 7, 9]
  end

  specify 'only even results' do
    Array(0..9).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:deliveries_cycle, results: :even)
    expect(cycle.current_deliveries.count).to eq 5
    expect(cycle.current_deliveries.pluck(:number)).to eq [2, 4, 6, 8, 10]
  end

  specify 'only Tuesday, in Janury, odd weeks, and even results' do
    Array(0..60).each do |i|
      create(:delivery, date: Date.today + i.day)
    end

    cycle = create(:deliveries_cycle,
      wdays: [2],
      months: [1],
      week_numbers: :odd,
      results: :even)
    expect(cycle.current_deliveries.count).to eq 1
    expect(cycle.current_deliveries.first.date.wday).to eq 2
    expect(cycle.current_deliveries.first.date.cweek).to eq 3
    expect(cycle.current_deliveries.first.number).to eq 18
  end
end
