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

  describe "usable scope" do
    specify "with email and not revoked" do
      session = create(:session, :admin, revoked_at: nil)
      expect(Session.usable).to include(session)
    end

    specify "without email" do
      session = create(:session, :admin, revoked_at: nil)
      session.update!(email: nil)
      expect(Session.usable).to be_empty
    end

    specify "revoked" do
      session = create(:session, :admin, :revoked)
      expect(Session.usable).to be_empty
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
  end

  specify "#revoke!" do
    session = create(:session, :admin)
    expect { session.revoke! }.to change(session, :revoked_at).from(nil)
    expect(session).to be_revoked
  end
end
