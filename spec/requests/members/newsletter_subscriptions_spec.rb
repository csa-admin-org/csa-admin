require "rails_helper"

describe "Newsletter subscriptions" do
  before { integration_session.host = "membres.ragedevert.test" }

  describe "unsubscribe" do
    specify "with POST request (List-Unsubscribe-Post)" do
      email = "joe@do.com"
      member = create(:member, emails: email)
      token = Newsletter::Audience.encrypt_email(email)

      expect {
        post "/newsletters/unsubscribe/#{token}/post"
      }.to change { EmailSuppression.active.count }.by(1)

      expect(response.status).to eq 200
    end

    specify "with invalid token" do
      expect {
        post "/newsletters/unsubscribe/foo/post"
      }.not_to change { EmailSuppression.active.count }

      expect(response.status).to eq 404
    end
  end
end
