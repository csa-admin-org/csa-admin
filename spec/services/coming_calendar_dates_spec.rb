require 'rails_helper'

describe ComingCalendarDates do
  fixtures :halfday_works
  subject { ComingCalendarDates.new }

  describe '.dates_with_participants_count' do
    subject { ComingCalendarDates.new.dates_with_participants_count }
    let(:beginning_of_week) { Date.today.beginning_of_week }

    it { is_expected.to be_kind_of(Hash) }
    it { is_expected.to include((beginning_of_week + 10.days).to_s => [1, 3]) }
  end
end
