# frozen_string_literal: true

module Checker
  class NewsletterStaleProcessing < SimpleDelegator
    def self.check_all!
      Newsletter::Delivery.stale.pluck(:newsletter_id).uniq.each do |newsletter_id|
        newsletter = Newsletter.find(newsletter_id)
        new(newsletter).check!
      end
    end

    def initialize(newsletter)
      super(newsletter)
    end

    def check!
      Error.notify("Newsletter stale delivery proccesing",
        newsletter_id: id,
        pending_deliveries: deliveries.processing.count)
    end
  end
end
