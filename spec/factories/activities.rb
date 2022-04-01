FactoryBot.define do
  factory :activity do
    date { Date.current.beginning_of_week + 8.days }
    start_time { '8:30' }
    end_time { '12:00' }
    place { 'Thielle' }
    title { 'Aide aux champs' }
  end
end
