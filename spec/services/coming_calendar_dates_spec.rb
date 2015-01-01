require 'rails_helper'

describe ComingCalendarDates do
  describe '.dates_with_participants_count' do
    subject { ComingCalendarDates.new.dates_with_participants_count }
    let(:beginning_of_week) { Date.today.beginning_of_week }
    before do
      create(:halfday_work, periods: ['am', 'pm'])
      create(:halfday_work, periods: ['am'])
    end

    it { is_expected.to be_kind_of(Hash) }
    it { is_expected.to include((beginning_of_week + 10.days).to_s => [2, 1]) }
  end
end
