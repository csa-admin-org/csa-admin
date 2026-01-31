# frozen_string_literal: true

require "faker"

module MembersHelper
  def build_member(attributes = {})
    Member.new({
      name: Faker::Name.unique.name,
      emails: [ Faker::Internet.unique.email, Faker::Internet.unique.email ].join(", "),
      phones: Faker::Base.unique.numerify("+41 ## ### ## ##"),
      street: Faker::Address.street_address,
      city: Faker::Address.city,
      zip: Faker::Address.zip,
      annual_fee: Current.org.annual_fee
    }.merge(attributes))
  end

  def create_member(attributes = {})
    build_member(attributes).tap(&:save!)
  end

  # Creates an inactive member with a session, ready to be discarded.
  # Useful for testing discard and anonymization flows.
  def discardable_member
    member = create_member
    member.update_columns(state: "inactive")
    member.sessions.create!(
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Agent")
    member
  end
end
