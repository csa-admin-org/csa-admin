# frozen_string_literal: true

FactoryBot.define do
  factory :basket do
    membership
    basket_size
    depot
    delivery
  end
end
