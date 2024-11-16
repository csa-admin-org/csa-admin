# frozen_string_literal: true

require "rails_helper"

describe MemberRegistration do
  def register(member, params)
    registration = described_class.new(member, params)
    registration.save
    registration.member
  end

  specify "do not persist invalid member" do
    member = build(:member, :waiting, name: "")

    expect {
      member = register(member, {})
    }.not_to change(Member, :count)

    expect(member).not_to be_persisted
    expect(member).not_to be_valid
    expect(member.errors[:name]).to be_present
  end

  specify "persist valid new member" do
    admin1 = create(:admin, notifications: [ "new_registration" ])
    create(:admin, notifications: [])

    member = build(:member, :waiting, name: "John Doe")

    expect {
      register(member, {})
    }.to change(Member, :count).by(1)

    perform_enqueued_jobs

    expect(AdminMailer.deliveries.size).to eq 1
    mail = AdminMailer.deliveries.last
    expect(mail.subject).to eq "Nouvelle inscription"
    expect(mail.to).to eq [ admin1.email ]
    expect(mail.body.encoded).to include admin1.name
    expect(mail.body.encoded).to include "John Doe"
  end

  specify "do not persist invalid new member and clear emails taken errors" do
    create(:member, :active, emails: "john@doe.com")
    member = build(:member, :waiting, phones: "", emails: "john@doe.com, wrong")
    member.public_create = true

    expect {
      member = register(member, { phones: "" })
    }.not_to change(Member, :count)

    expect(member).not_to be_persisted
    expect(member.errors[:phones]).to be_present
    expect(member.errors[:emails]).to eq [ "n'est pas valide" ]
  end

  specify "do not persit existing and active member" do
    create(:member, :active, emails: "john@doe.com")
    member = build(:member, :waiting, emails: "john@doe.com")

    expect {
      member = register(member, {})
    }.not_to change(Member, :count)

    expect(member).not_to be_valid
    expect(member.errors[:emails]).to be_present
  end

  specify "put back in waiting list matching inactive member" do
    admin = create(:admin, notifications: [ "new_registration" ])
    inactive_member = create(:member, :inactive, name: "John Doe", emails: "john@doe.com")
    member = build(:member, :waiting, emails: "john@doe.com")

    expect {
      expect {
        member = register(member, name: "Doe John", waiting_basket_size_id: 1)
      }.to change { inactive_member.reload.state }.from("inactive").to("waiting")
    }.not_to change(Member, :count)

    expect(member).to be_persisted
    expect(member).to be_valid
    expect(member.id).to eq inactive_member.id
    expect(member.name).to eq "Doe John"
    expect(member.waiting_basket_size_id).to eq 1

    perform_enqueued_jobs
    expect(AdminMailer.deliveries.size).to eq 1
    mail = AdminMailer.deliveries.last
    expect(mail.subject).to eq "Nouvelle réinscription"
    expect(mail.to).to eq [ admin.email ]
    expect(mail.body.encoded).to include admin.name
    expect(mail.body.encoded).to include "Un membre existant"
    expect(mail.body.encoded).to include "Doe John"
  end

  specify "put back in support only matching inactive member" do
    Current.org.update!(annual_fee: 30)
    inactive_member = create(:member, :inactive, annual_fee: 0, name: "John Doe", emails: "john@doe.com")
    member = build(:member, :waiting, emails: "john@doe.com")

    expect {
      expect {
        member = register(member, name: "Doe John", waiting_basket_size_id: "0")
      }.to change { inactive_member.reload.state }.from("inactive").to("support")
    }.not_to change(Member, :count)

    expect(member).to be_persisted
    expect(member).to be_valid
    expect(member.id).to eq inactive_member.id
    expect(member.name).to eq "Doe John"
    expect(member.waiting_basket_size_id).to be_nil
    expect(member.annual_fee).to eq 30
  end
end
