# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    trait :member do
      member
      email { member.emails_array.first }
    end

    trait :admin do
      admin
      email { admin.email }
    end

    trait :revoked do
      revoked_at { Time.current }
    end

    remote_addr { "127.0.0.1" }
    user_agent { "a browser user agent" }
  end
end
