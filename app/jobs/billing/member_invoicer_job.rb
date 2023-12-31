module Billing
  class MemberInvoicerJob < ApplicationJob
    queue_as :low

    def perform(member)
      if Current.acp.share?
        Billing::InvoicerACPShare.invoice(member, send_email: true)
      end
      if Current.acp.feature?("new_member_fee")
        Billing::InvoicerNewMemberFee.invoice(member, send_email: true)
      end
      Billing::Invoicer.invoice(member, send_email: true)
    end
  end
end
