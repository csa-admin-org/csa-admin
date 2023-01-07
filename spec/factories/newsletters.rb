FactoryBot.define do
  factory :newsletter do
    subject { 'Hello' }
    association :template, factory: :newsletter_template
  end
end
