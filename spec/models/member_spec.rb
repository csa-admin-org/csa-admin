require 'rails_helper'

describe Member do
  describe '#emails=' do
    it 'parses emails list' do
      member = Member.new(emails: 'john@doe.com, foo@bar.com')
      expect(member.emails).to eq %w[john@doe.com foo@bar.com]
    end
  end

  describe '#phones=' do
    it 'parses phones list' do
      member = Member.new(phones: '1234, 4567')
      expect(member.phones).to eq %w[1234 4567]
    end
  end
end
