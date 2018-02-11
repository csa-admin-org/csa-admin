require 'rails_helper'

describe ACP do
  describe '#summer_month_range' do
    it 'saves summer_month_range from min/max' do
      acp = create(:acp,
        summer_month_range_min: 4,
        summer_month_range_max: 9)
      acp.reload

      expect(acp.summer_month_range).to eq 4...10
      expect(acp.summer_month_range).not_to include 3
      expect(acp.summer_month_range).to include 4
      expect(acp.summer_month_range).to include 9
      expect(acp.summer_month_range).not_to include 10
    end

    it 'sets summer_month_range to nil when min/max are blanc' do
      acp = create(:acp,
        summer_month_range_min: '',
        summer_month_range_max: '')
      expect(acp.summer_month_range).to be_nil
    end

    it 'validates summer_month_range min/max are not present' do
      acp = ACP.new(
        summer_month_range_min: nil,
        summer_month_range_max: '')
      expect(acp).to have_valid(:summer_month_range_min)
      expect(acp).to have_valid(:summer_month_range_max)
    end

    it 'validates summer_month_range min presence when max is present' do
      acp = ACP.new(
        summer_month_range_min: nil,
        summer_month_range_max: 12)
      expect(acp).not_to have_valid(:summer_month_range_min)
    end

    it 'validates summer_month_range max presence when min is present' do
      acp = ACP.new(
        summer_month_range_min: 1,
        summer_month_range_max: nil)
      expect(acp).not_to have_valid(:summer_month_range_max)
    end

    it 'validates that summer_month_range inclusion' do
      acp = ACP.new(
        summer_month_range_min: 0,
        summer_month_range_max: 13)
      expect(acp).not_to have_valid(:summer_month_range_min)
      expect(acp).not_to have_valid(:summer_month_range_max)
    end

    it 'validates that summer_month_range max is greater or equal than max' do
      acp = ACP.new(
        summer_month_range_min: 10,
        summer_month_range_max: 9)
      expect(acp).not_to have_valid(:summer_month_range_max)
    end
  end

  describe '#season_for' do
    it 'returns summer or winter' do
      acp = ACP.new(summer_month_range: 4..9)

      expect(acp.season_for(3)).to eq 'winter'
      expect(acp.season_for(4)).to eq 'summer'
      expect(acp.season_for(7)).to eq 'summer'
      expect(acp.season_for(9)).to eq 'summer'
      expect(acp.season_for(10)).to eq 'winter'
    end

    it 'raise when month is out of range' do
      acp = ACP.new(summer_month_range: 4..9)
      expect { acp.season_for(13) }.to raise_error(ArgumentError)
    end

    it 'raises when seasons not configured' do
      acp = ACP.new(summer_month_range: nil)
      expect { acp.season_for(1) }.to raise_error('winter/summer seasons not configured')
    end
  end
end
