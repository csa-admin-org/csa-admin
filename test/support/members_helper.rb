# frozen_string_literal: true

require "faker"

module MembersHelper
  def create_member(attributes = {})
    Member.create!({
      name: Faker::Name.unique.name,
      emails: [ Faker::Internet.unique.email, Faker::Internet.unique.email ].join(", "),
      phones: Faker::Base.unique.numerify("+41 ## ### ## ##"),
      address: Faker::Address.street_address,
      city: Faker::Address.city,
      zip: Faker::Address.zip,
      annual_fee: Current.org.annual_fee
    }.merge(attributes))
  end
end
