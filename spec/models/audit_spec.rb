# frozen_string_literal: true

require "rails_helper"

describe Auditable do
  specify "save changes on audited attributes without session" do
    member = create(:member, name: "Joe Doe")

    expect {
      member.update!(name: "John Doe")
    }.to change(Audit, :count).by(1)

    expect(member.audits.last).to have_attributes(
      actor: System.instance,
      session: nil,
      audited_changes: {
        "name" => [ "Joe Doe", "John Doe" ]
      })
  end

  specify "save changes on audited attributes with current session" do
    member = create(:member, name: "Joe Doe")
    session = create(:session, member: member)
    Current.session = session

    expect {
      member.update!(name: "John Doe", note: "Doo")
    }.to change(Audit, :count).by(1)

    expect(member.audits.last).to have_attributes(
      actor: member,
      session: session,
      audited_changes: {
        "name" => [ "Joe Doe", "John Doe" ],
        "note" => [ nil, "Doo" ]
      })
  end

  specify "ignore changes with no present value" do
    member = create(:member, note: nil)

    expect {
      member.update!(note: "  ")
    }.not_to change(Audit, :count)
  end

  specify "ignore changes with similar values" do
    member = create(:member, note: "Foo")

    expect {
      member.update!(note: "  Foo ")
    }.not_to change(Audit, :count)
  end
end
