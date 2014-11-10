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
end
