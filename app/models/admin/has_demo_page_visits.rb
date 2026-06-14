# frozen_string_literal: true

class Admin
  module HasDemoPageVisits
    extend ActiveSupport::Concern

    included do
      has_many :demo_page_visits, class_name: "Demo::PageVisit", dependent: :delete_all
    end

    def demo_page_visits_count
      demo_page_visits.count
    end

    def demo_meaningful_page_visits_count
      meaningful_demo_page_visits.count
    end

    def demo_distinct_meaningful_page_keys_count
      meaningful_demo_page_visits.distinct.count(:page_key)
    end

    def last_demo_page_visit_at
      meaningful_demo_page_visits.maximum(:created_at)
    end

    def meaningfully_explored_demo?
      demo_meaningful_page_visits_count >= 2 && demo_distinct_meaningful_page_keys_count >= 2
    end

    private

    def meaningful_demo_page_visits
      demo_page_visits.meaningful
    end
  end
end
