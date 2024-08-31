# frozen_string_literal: true

module Billing
  class MemberInvoicerJob < ApplicationJob
    queue_as :low

    def perform(member)
      if Current.org.share?
        Billing::InvoicerShare.invoice(member, send_email: true)
      end
      if Current.org.feature?("new_member_fee")
        Billing::InvoicerNewMemberFee.invoice(member, send_email: true)
      end
      Billing::Invoicer.invoice(member, send_email: true)
    end
  end
end
