FactoryBot.define do
  factory :newsletter do
    subject { 'Hello' }
    audience { 'member_state:all' }
    association :template, factory: :newsletter_template
  end
end
