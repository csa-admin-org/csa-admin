# frozen_string_literal: true

class MembershipFutureBillingJob < ApplicationJob
  queue_as :default

  def perform(membership)
    Billing::InvoicerFuture.invoice(membership, send_email: true)
  end
end
