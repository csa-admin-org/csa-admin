# frozen_string_literal: true

FactoryBot.define do
  factory :depot_group do
    name { Faker::Address.unique.city }
    public_name { "#{name} PUBLIC" }
  end
end
