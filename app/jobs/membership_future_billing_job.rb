# frozen_string_literal: true

class MembershipFutureBillingJob < ApplicationJob
  queue_as :default

  def perform(membership)
    invoicer = Billing::Invoicer.new(membership.member,
      membership: membership,
      period_date: membership.started_on,
      billing_year_division: 1)
    invoicer.invoice(send_email: true)
  end
end
