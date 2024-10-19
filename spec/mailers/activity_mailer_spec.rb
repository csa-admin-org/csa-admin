# frozen_string_literal: true

require "rails_helper"

describe ActivityMailer do
  before { Current.org.update!(activity_phone: "+41 77 333 44 55") }
  let(:member) { create(:member, emails: "example@csa-admin.org") }
  let(:activity) {
    create(:activity,
      date: "24.03.2020",
      start_time: Time.zone.parse("8:30"),
      end_time: Time.zone.parse("12:00"),
      place: "Thielle",
      title: "Aide aux champs",
      description: "Que du bonheur")
   }
  let(:participation) {
    create(:activity_participation,
      member: member,
      activity: activity,
      participants_count: 2)
  }

  specify "#participation_reminder_email" do
    template = MailTemplate.find_by(title: "activity_participation_reminder")
    create(:activity_participation, :carpooling,
      activity: activity,
      member: create(:member, name: "Elea Asah"),
      carpooling_phone: "+41765431243",
      carpooling_city: "La Chaux-de-Fonds")
    group = ActivityParticipationGroup.group([ participation ]).first

    mail = ActivityMailer.with(
      template: template,
      activity_participation_ids: group.ids,
    ).participation_reminder_email

    expect(mail.subject).to eq("Activité à venir (24 mars 2020)")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("activity-participation-reminder")
    expect(mail.body).to include("<strong>Date:</strong> mardi 24 mars 2020")
    expect(mail.body).to include("<strong>Horaire:</strong> 8:30-12:00")
    expect(mail.body).to include("<strong>Lieu:</strong> Thielle")
    expect(mail.body).to include("<strong>Activité:</strong> Aide aux champs")
    expect(mail.body).to include("<strong>Description:</strong> Que du bonheur")
    expect(mail.body).to include("<strong>Participants:</strong> 2")
    expect(mail.body).to include("<strong>+41 77 333 44 55</strong>")
    expect(mail.body).to include("<strong>Elea Asah</strong>: +41 76 543 12 43 (La Chaux-de-Fonds)")
    expect(mail.body).to include("https://membres.organization.test/activity_participations")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@organization.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end

  specify "#participation_validated_email" do
    template = MailTemplate.find_by(title: "activity_participation_validated")

    mail = ActivityMailer.with(
      template: template,
      activity_participation_ids: participation.id
    ).participation_validated_email

    expect(mail.subject).to eq("Activité validée 🎉")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("activity-participation-validated")
    expect(mail.body).to include("<strong>Date:</strong> mardi 24 mars 2020")
    expect(mail.body).to include("<strong>Horaire:</strong> 8:30-12:00")
    expect(mail.body).to include("<strong>Lieu:</strong> Thielle")
    expect(mail.body).to include("<strong>Activité:</strong> Aide aux champs")
    expect(mail.body).to include("<strong>Description:</strong> Que du bonheur")
    expect(mail.body).to include("<strong>Participants:</strong> 2")
    expect(mail.body).to include("<strong>+41 77 333 44 55</strong>")
    expect(mail.body).to include("https://membres.organization.test/activity_participations")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@organization.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end

  specify "#participation_rejected_email" do
    template = MailTemplate.find_by(title: "activity_participation_rejected")

    mail = ActivityMailer.with(
      template: template,
      activity_participation_ids: participation.id
    ).participation_rejected_email

    expect(mail.subject).to eq("Activité refusée 😬")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("activity-participation-rejected")
    expect(mail.body).to include("<strong>Date:</strong> mardi 24 mars 2020")
    expect(mail.body).to include("<strong>Horaire:</strong> 8:30-12:00")
    expect(mail.body).to include("<strong>Lieu:</strong> Thielle")
    expect(mail.body).to include("<strong>Activité:</strong> Aide aux champs")
    expect(mail.body).to include("<strong>Description:</strong> Que du bonheur")
    expect(mail.body).to include("<strong>Participants:</strong> 2")
    expect(mail.body).to include("<strong>+41 77 333 44 55</strong>")
    expect(mail.body).to include("https://membres.organization.test/activity_participations")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@organization.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end
end
