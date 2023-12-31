require "rails_helper"

describe "Member sessions" do
  before { Capybara.app_host = "http://membres.ragedevert.test" }

  it "creates a new session from email", sidekiq: :inline do
    member = create(:member, emails: "thibaud@thibaud.gg, john@doe.com")

    visit "/"
    expect(current_path).to eq "/login"
    expect(page).to have_content "Merci de vous authentifier pour accéder à votre compte."

    fill_in "session_email", with: " thibaud@Thibaud.GG "
    click_button "Envoyer"

    session = member.sessions.last

    expect(session.email).to eq "thibaud@thibaud.gg"
    expect(SessionMailer.deliveries.size).to eq 1

    expect(current_path).to eq "/login"
    expect(page).to have_content "Merci! Un email vient de vous être envoyé."

    open_email("thibaud@thibaud.gg")
    current_email.click_link "Accéder à mon compte"

    expect(current_path).to eq "/activity_participations"
    expect(page).to have_content "Vous êtes maintenant connecté."

    delete_session(member)
    visit "/"

    expect(current_path).to eq "/login"
    expect(page).to have_content "Merci de vous authentifier pour accéder à votre compte."
  end

  it "redirects to billing when activity is not a feature" do
    current_acp.update!(features: [])

    login(create(:member))

    expect(current_path).to eq "/billing"
  end

  it "does not accept blank email" do
    visit "/"
    expect(current_path).to eq "/login"

    fill_in "session_email", with: ""
    click_button "Envoyer"

    expect(SessionMailer.deliveries.size).to eq 0

    expect(current_path).to eq "/sessions"
    expect(page).to have_selector("span.error", text: "n'est pas valide")
  end

  it "does not accept invalid email" do
    visit "/"
    expect(current_path).to eq "/login"

    fill_in "session_email", with: "foo@bar"
    click_button "Envoyer"

    expect(SessionMailer.deliveries.size).to eq 0

    expect(current_path).to eq "/sessions"
    expect(page).to have_selector("span.error", text: "n'est pas valide")
  end

  it "does not accept email with invalid character" do
    visit "/"
    expect(current_path).to eq "/login"

    fill_in "session_email", with: "foo@bar.com)"
    click_button "Envoyer"

    expect(SessionMailer.deliveries.size).to eq 0

    expect(current_path).to eq "/sessions"
    expect(page).to have_selector("span.error", text: "Email inconnu")
  end

  it "does not accept partial email matching other" do
    create(:member, emails: "thibaud@thibaud.gg, john@doe.com")

    visit "/"
    expect(current_path).to eq "/login"

    fill_in "session_email", with: "hn@doe.com"
    click_button "Envoyer"

    expect(SessionMailer.deliveries).to be_empty

    expect(current_path).to eq "/sessions"
    expect(page).to have_selector("span.error", text: "Email inconnu")
  end

  it "does not accept unknown email" do
    visit "/"
    expect(current_path).to eq "/login"

    fill_in "session_email", with: "unknown@member.com"
    click_button "Envoyer"

    expect(SessionMailer.deliveries).to be_empty

    expect(current_path).to eq "/sessions"
    expect(page).to have_selector("span.error", text: "Email inconnu")
  end

  it "does not accept old session when not logged in" do
    old_session = create(:session, :member, created_at: 1.hour.ago)

    visit "/sessions/#{old_session.token}"

    expect(current_path).to eq "/login"
    expect(page).to have_content "Votre lien de connexion n'est plus valide, merci d'en demander un nouveau."
  end

  it "handles old session when already logged in" do
    member = create(:member)
    login(member)
    old_session = create(:session, member: member, created_at: 1.hour.ago)

    visit "/sessions/#{old_session.token}"

    expect(current_path).to eq "/activity_participations"
    expect(page).to have_content "Vous êtes déjà connecté."
  end

  it "logout session without email" do
    member = create(:member)
    login(member)
    member.sessions.last.update!(email: nil)

    visit "/"

    expect(current_path).to eq "/login"
    expect(page).to have_content "Votre session a expirée, merci de vous authentifier à nouveau."

    visit "/"

    expect(current_path).to eq "/login"
    expect(page).to have_content "Merci de vous authentifier pour accéder à votre compte."
  end

  it "logout expired session" do
    member = create(:member)
    login(member)
    member.sessions.last.update!(created_at: 1.year.ago)

    visit "/"

    expect(current_path).to eq "/login"
    expect(page).to have_content "Votre session a expirée, merci de vous authentifier à nouveau."

    visit "/"

    expect(current_path).to eq "/login"
    expect(page).to have_content "Merci de vous authentifier pour accéder à votre compte."
  end

  it "update last usage column every hour when using the session" do
    member = create(:member)

    travel_to Time.new(2018, 7, 6, 1) do
      login(member)

      expect(member.sessions.last).to have_attributes(
        last_used_at: Time.new(2018, 7, 6, 1),
        last_remote_addr: "127.0.0.1",
        last_user_agent: "-")
    end

    travel_to Time.new(2018, 7, 6, 1, 59) do
      visit "/"
      expect(member.sessions.last).to have_attributes(
        last_used_at: Time.new(2018, 7, 6, 1))
    end

    travel_to Time.new(2018, 7, 6, 2, 0, 1) do
      visit "/"
      expect(member.sessions.last).to have_attributes(
        last_used_at: Time.new(2018, 7, 6, 2, 0, 1))
    end
  end
end
