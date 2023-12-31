require "rails_helper"

describe SessionMailer do
  specify "#new_member_session_email" do
    session = Session.new(
      member: Member.new(language: "fr"),
      email: "example@acp-admin.ch")
    mail = SessionMailer.with(
      session: session,
      session_url: "https://example.com/session/token",
    ).new_member_session_email

    expect(mail.subject).to eq("Connexion à votre compte")
    expect(mail.to).to eq([ "example@acp-admin.ch" ])
    expect(mail.body).to include("Accéder à mon compte")
    expect(mail.body).to include("https://example.com/session/token")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@ragedevert.ch>"
  end

  specify "#new_admin_session_email" do
    session = Session.new(
      admin: Admin.new(language: "fr"),
      email: "example@acp-admin.ch")
    mail = SessionMailer.with(
      session: session,
      session_url: "https://example.com/session/token",
    ).new_admin_session_email

    expect(mail.subject).to eq("Connexion à votre compte admin")
    expect(mail.to).to eq([ "example@acp-admin.ch" ])

    expect(mail.body).to include("Accéder à mon compte admin")
    expect(mail.body).to include("https://example.com/session/token")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@ragedevert.ch>"
  end
end
