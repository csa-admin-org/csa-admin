# frozen_string_literal: true

FactoryBot.define do
  factory :newsletter_segment, class: Newsletter::Segment do
    title { "Segment" }
  end
end
