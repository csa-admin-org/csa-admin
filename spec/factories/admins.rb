# frozen_string_literal: true

FactoryBot.define do
  factory :admin do
    name { "Bob" }
    email { Faker::Internet.unique.email }
    permission { Permission.superadmin }
  end
end
