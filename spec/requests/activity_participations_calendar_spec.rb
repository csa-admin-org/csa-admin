require "rails_helper"

describe "Activity Particiations calendar feed" do
  before { integration_session.host = "admin.ragedevert.test" }

  specify "without auth token" do
    Current.acp.update!(icalendar_auth_token: nil)
    get "/activity_participations/calendar.ics"
    expect(response.status).to eq 401
  end

  specify "with a wrong auth token" do
    get "/activity_participations/calendar.ics", params: { auth_token: "wrong" }
    expect(response.status).to eq 401
  end

  specify "with a good auth token" do
    participation = create(:activity_participation, participants_count: 3)
    auth_token = Current.acp.icalendar_auth_token
    get "/activity_participations/calendar.ics", params: { auth_token: auth_token }
    expect(response.status).to eq 200
    expect(response.headers["Content-Type"]).to eq "text/calendar; charset=utf-8"
    expect(response.body).to include "#{participation.member.name} (3)"
  end
end
