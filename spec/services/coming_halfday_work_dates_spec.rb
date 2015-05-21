require 'rails_helper'

describe ComingHalfdayWorkDates do
  describe '#dates_with_participants_count' do
    subject { ComingHalfdayWorkDates.new.dates_with_participants_count }
    let(:beginning_of_week) { Date.today.beginning_of_week }
    before do
      create(:halfday_work_date, periods: ['am'])
      create(:halfday_work, periods: ['am', 'pm'])
      create(:halfday_work, periods: ['am'])
    end

    it { is_expected.to be_kind_of(Hash) }
    it { is_expected.to include((beginning_of_week + 8.days).to_s => [2, nil]) }
  end

  describe '#min / #max' do
    subject { ComingHalfdayWorkDates.new }
    before do
      create(:halfday_work_date, date: Date.today.next_week + 2.days)
      create(:halfday_work_date, date: Date.today.next_month)
    end

    specify { expect(subject.min).to eq Date.today.next_week + 2.days }
    specify { expect(subject.max).to eq Date.today.next_month }
  end
end
