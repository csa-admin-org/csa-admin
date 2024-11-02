# frozen_string_literal: true

require "rails_helper"

describe SessionMailer do
  specify "#new_member_session_email" do
    session = Session.new(
      member: Member.new(language: "fr"),
      email: "example@csa-admin.org")
    mail = SessionMailer.with(
      session: session,
      session_url: "https://example.com/session/token",
    ).new_member_session_email

    expect(mail.subject).to eq("Connexion à votre compte")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("session-member")

    expect(mail.body).to include("Accéder à mon compte")
    expect(mail.body).to include("https://example.com/session/token")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"
  end

  specify "#new_admin_session_email" do
    session = Session.new(
      admin: Admin.new(language: "fr"),
      email: "example@csa-admin.org")
    mail = SessionMailer.with(
      session: session,
      session_url: "https://example.com/session/token",
    ).new_admin_session_email

    expect(mail.subject).to eq("Connexion à votre compte admin")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("session-admin")

    expect(mail.body).to include("Accéder à mon compte admin")
    expect(mail.body).to include("https://example.com/session/token")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"
  end
end
