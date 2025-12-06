# frozen_string_literal: true

module Billing
  class InvoiceOverdueNoticeJob < ApplicationJob
    queue_as :default

    def perform(invoice)
      InvoiceOverdueNotice.deliver(invoice)
    end
  end
end
