# frozen_string_literal: true

require "rails_helper"

describe Session do
  describe "validations" do
    specify "email_must_not_be_suppressed" do
      create(:member, emails: "john@doe.com")
      session = build(:session, member_email: "john@doe.com")
      expect(session).to have_valid(:email)

      create(:email_suppression, stream_id: "broadcast", email: "john@doe.com")
      expect(session).to have_valid(:email)

      create(:email_suppression, stream_id: "outbound", email: "john@doe.com")
      expect(session).not_to have_valid(:email)
    end
  end

  describe "#expired?" do
    it "expires after a year" do
      session = build(:session,
        email: "john@doe.com",
        created_at: Time.current)
      expect(session).not_to be_expired
      travel 1.year + 1.second do
        expect(session).to be_expired
      end
    end

    it "expires after an hour for member session orginated from admin" do
      session = build(:session, :member, :admin,
        email: "admin@joe.com",
        created_at: Time.current)
      expect(session).to be_admin_originated
      expect(session).not_to be_expired
      travel 6.hours + 1.second do
        expect(session).to be_expired
      end
    end

    it "expires directly when no email" do
      session = build(:session,
        email: nil,
        created_at: Time.current)
      expect(session.email).to be_nil
      expect(session).to be_expired
    end
  end
end
