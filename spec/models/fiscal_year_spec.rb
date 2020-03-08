require 'rails_helper'

describe FiscalYear do
  describe '.current' do
    context 'with start_month 1' do
      let(:fy) { FiscalYear.current }

      specify 'beginning of year' do
        Timecop.freeze '2017-1-1' do
          expect(fy.beginning_of_year).to eq Date.new(2017, 1, 1)
          expect(fy.end_of_year).to eq Date.new(2017, 12, 31)
        end
      end

      specify 'end of year' do
        Timecop.freeze '2017-12-31' do
          expect(fy.beginning_of_year).to eq Date.new(2017, 1, 1)
          expect(fy.end_of_year).to eq Date.new(2017, 12, 31)
        end
      end
    end

    context 'with start_month 4' do
      let(:fy) { FiscalYear.current(start_month: 4) }

      specify 'beginning of year' do
        Timecop.freeze '2017-1-1' do
          expect(fy.beginning_of_year).to eq Date.new(2016, 4, 1)
          expect(fy.end_of_year).to eq Date.new(2017, 3, 31)
          expect(fy.year).to eq 2016
        end
      end

      specify 'end of fiscal year' do
        Timecop.freeze '2017-3-31' do
          expect(fy.beginning_of_year).to eq Date.new(2016, 4, 1)
          expect(fy.end_of_year).to eq Date.new(2017, 3, 31)
          expect(fy.year).to eq 2016
        end
      end

      specify 'beginning of fiscal year' do
        Timecop.freeze '2017-4-1' do
          expect(fy.beginning_of_year).to eq Date.new(2017, 4, 1)
          expect(fy.end_of_year).to eq Date.new(2018, 3, 31)
          expect(fy.year).to eq 2017
        end
      end

      specify 'end of year' do
        Timecop.freeze '2017-12-31' do
          expect(fy.beginning_of_year).to eq Date.new(2017, 4, 1)
          expect(fy.end_of_year).to eq Date.new(2018, 3, 31)
          expect(fy.year).to eq 2017
        end
      end
    end
  end

  describe '.for' do
    it 'accepts past year' do
      fy = FiscalYear.for(2017, start_month: 4)
      expect(fy.beginning_of_year).to eq Date.new(2017, 4, 1)
      expect(fy.end_of_year).to eq Date.new(2018, 3, 31)
    end

    it 'accepts futur year' do
      fy = FiscalYear.for(2042, start_month: 4)
      expect(fy.beginning_of_year).to eq Date.new(2042, 4, 1)
      expect(fy.end_of_year).to eq Date.new(2043, 3, 31)
    end

    it 'accepts past date' do
      fy = FiscalYear.for(Date.new(2017, 3, 31), start_month: 4)
      expect(fy.beginning_of_year).to eq Date.new(2016, 4, 1)
      expect(fy.end_of_year).to eq Date.new(2017, 3, 31)
    end

    it 'accepts past date' do
      fy = FiscalYear.for(Date.new(2018, 4, 30), start_month: 4)
      expect(fy.beginning_of_year).to eq Date.new(2018, 4, 1)
      expect(fy.end_of_year).to eq Date.new(2019, 3, 31)
    end
  end

  describe '#month' do
    it 'returns same month number when with start_month 1' do
      today = Date.current
      fy = FiscalYear.current
      expect(fy.month(today)).to eq today.month
    end

    it 'returns month number since beginning_of_year' do
      fy = FiscalYear.for(2017, start_month: 4)
      expect(fy.month(Date.new(2017, 4, 1))).to eq 1
      expect(fy.month(Date.new(2017, 12, 1))).to eq 9
      expect(fy.month(Date.new(2018, 3, 1))).to eq 12
    end
  end

  describe '#current_quarter_range' do
    it 'returns Q3 range', freeze: '12-08-2020' do
      fy = FiscalYear.for(2020)
      expect(fy.current_quarter_range).to eq Time.new(2020, 7)..Time.new(2020, 9, 30).end_of_day
    end

    it 'returns Q2 range', freeze: '31-08-2020' do
      fy = FiscalYear.for(2020, start_month: 4)
      expect(fy.current_quarter_range).to eq Time.new(2020, 7)..Time.new(2020, 9, 30).end_of_day
    end

    it 'returns Q4 range', freeze: '01-01-2020' do
      fy = FiscalYear.for(2020, start_month: 2)
      Timecop.freeze(fy.end_of_year)
      expect(fy.current_quarter_range).to eq Time.new(2020, 11)..Time.new(2021, 1, 31).end_of_day
    end

    it 'returns Q1 range', freeze: '01-01-2020' do
      fy = FiscalYear.for(2020, start_month: 3)
      Timecop.freeze('01-03-2020')
      expect(fy.current_quarter_range).to eq Time.new(2020, 3)..Time.new(2020, 5, 31).end_of_day
    end
  end
end
