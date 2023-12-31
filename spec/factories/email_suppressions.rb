FactoryBot.define do
  factory :email_suppression do
    stream_id { "outbound" }
    email { Faker::Internet.unique.email }
    reason { "HardBounce" }
    origin { "Recipient" }
  end
end
