require 'spec_helper'

shared_examples_for 'bulk_dates_insert' do
  let(:model) { build(described_class.to_s.underscore, date: nil) }

  describe 'validations' do

  end

  describe '#bulk_dates' do
    it 'is nil with a date set' do
      model.date = Date.today
      expect(model.bulk_dates).to be_nil
    end

    it 'includes all the days between starts and ends dates' do
      model.bulk_dates_starts_on = Date.today
      model.bulk_dates_ends_on = Date.tomorrow
      model.bulk_dates_weeks_frequency = 1
      model.bulk_dates_wdays = Array(0..6)

      expect(model.bulk_dates).to eq [
        Date.today,
        Date.tomorrow
      ]
    end

    it 'includes all the days between starts and ends dates following wdays' do
      model.bulk_dates_starts_on = Date.today.monday
      model.bulk_dates_ends_on = Date.today.sunday
      model.bulk_dates_weeks_frequency = 1
      model.bulk_dates_wdays = [0, 1, 2]

      expect(model.bulk_dates).to eq [
        Date.today.monday,
        Date.today.monday + 1.day,
        Date.today.sunday
      ]
    end

    it 'includes all the days between starts and ends dates following wdays' do
      model.bulk_dates_starts_on = Date.today.monday
      model.bulk_dates_ends_on = Date.today.sunday + 1.month
      model.bulk_dates_weeks_frequency = 2
      model.bulk_dates_wdays = [1]

      expect(model.bulk_dates).to eq [
        Date.today.monday,
        Date.today.monday + 2.weeks,
        Date.today.monday + 4.weeks
      ]
    end
  end

  describe '#save' do
    it 'includes all the days between starts and ends dates following wdays' do
      model.bulk_dates_starts_on = Date.today.monday
      model.bulk_dates_ends_on = Date.today.sunday + 1.month
      model.bulk_dates_weeks_frequency = 2
      model.bulk_dates_wdays = Array(0..6)

      expect(model.bulk_dates.size).to eq 21
      expect { model.save }.to change(model.class, :count).by(21)
    end
  end
end
