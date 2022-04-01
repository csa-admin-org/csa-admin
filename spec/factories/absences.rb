FactoryBot.define do
  factory :absence do
    member
    started_on { Absence.min_started_on }
    ended_on { Absence.min_started_on + 1.week }
  end
end
