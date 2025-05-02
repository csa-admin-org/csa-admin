# frozen_string_literal: true

module Scheduled
  class NewslettersSenderJob < BaseJob
    def perform
      Newsletter.schedulable.find_each do |newsletter|
        newsletter.send!
      end
    end
  end
end
