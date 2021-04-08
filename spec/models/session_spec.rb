require 'rails_helper'

describe Session do
  describe '#expired?' do
    it 'expires after a year' do
      session = build(:session,
        email: 'john@doe.com',
        created_at: Time.current)
      expect(session).not_to be_expired
      travel 1.year + 1.second do
        expect(session).to be_expired
      end
    end

    it 'expires after an hour for Admin ID session' do
      session = build(:session, :member,
        email: 'admin@doe.com',
        created_at: Time.current,
        user_agent: 'Admin ID: 1234')
      expect(session).not_to be_expired
      travel 1.hour + 1.second do
        expect(session).to be_expired
      end
    end

    it 'expires directly when no email' do
      session = build(:session,
        email: nil,
        created_at: Time.current)
      expect(session.email).to be_nil
      expect(session).to be_expired
    end
  end
end
