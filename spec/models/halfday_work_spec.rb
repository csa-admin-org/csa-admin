require 'rails_helper'

describe HalfdayWork do
  fixtures :members
  let(:member) { Member.first }

  describe 'validations' do
    describe 'date' do
      let(:halfday_work) { HalfdayWork.new(member: member, periods: ['am']) }

      it 'does not accept date in the past' do
        halfday_work.date = Date.yesterday
        expect(halfday_work).not_to be_valid
      end

      it 'accepts date after or on today' do
        halfday_work.date = Date.today
        expect(halfday_work).to be_valid
      end
    end

    describe 'periods' do
      let(:halfday_work) { HalfdayWork.new(member: member, date: Date.today) }

      it 'does accept good period value' do
        halfday_work.periods = %w[am pm]
        expect(halfday_work).to be_valid
      end

      it 'does not accept wrong period value' do
        halfday_work.periods = ['foo']
        expect(halfday_work).not_to be_valid
      end

      it 'does not accept no periods' do
        halfday_work.periods = nil
        expect(halfday_work).not_to be_valid
      end
    end
  end

  describe '#status' do
    context 'when validated' do
      subject { HalfdayWork.new(validated_at: Time.now).status }
      it { is_expected.to eq 'validated' }
    end

    context 'when rejected' do
      subject { HalfdayWork.new(rejected_at: Time.now).status }
      it { is_expected.to eq 'rejected' }
    end
  end

  describe '#period_am|pm' do
    let(:halfday_work) { HalfdayWork.new(periods: ['am']) }
    specify { expect(halfday_work.period_am).to eq true }
    specify { expect(halfday_work.period_pm).to eq false }
  end

  describe '#period_am=' do
    let(:halfday_work) { HalfdayWork.new(period_am: '1') }
    specify { expect(halfday_work.period_am).to eq true }
    specify { expect(halfday_work.period_pm).to eq false }
  end

  describe '#am|pm?' do
    let(:halfday_work) { HalfdayWork.new(periods: ['pm']) }
    specify { expect(halfday_work.am?).to eq false }
    specify { expect(halfday_work.pm?).to eq true }
  end
end
