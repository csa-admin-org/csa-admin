require 'rails_helper'

describe HalfdayWork do
  fixtures :members
  let(:member) { Member.first }

  describe 'validations' do
    let(:halfday_work) { HalfdayWork.new(member: member, period: 'am') }

    it 'does not accept date in the past' do
      halfday_work.date = Date.yesterday
      expect(halfday_work).not_to be_valid
    end

    it 'accepts date after or on today' do
      halfday_work.date = Date.today
      expect(halfday_work).to be_valid
    end
  end
end
