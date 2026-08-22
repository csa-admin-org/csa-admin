# frozen_string_literal: true

module InvoicesHelper
  def create_annual_fee_invoice(attrs = {})
    create_invoice({
      entity_type: "AnnualFee",
      annual_fee: 30
    }.merge(attrs))
  end

  def create_membership_invoice(attrs = {})
    create_invoice({
      entity: memberships(:john),
      membership_amount_fraction: 1,
      memberships_amount_description: "Annual amount"
    }.merge(attrs))
  end

  def create_other_invoice(attrs = {})
    amount = attrs.delete(:amount) || 10
    create_invoice({
      entity_type: "Other",
      items_attributes: {
        "0" => { description: "Other", amount: amount }
      }
    }.merge(attrs))
  end

  def create_invoice(attrs = {})
    invoice = Invoice.create!({
      member: members(:john),
      date: Date.current
    }.merge(attrs))
    perform_enqueued_jobs
    invoice.reload
    invoice
  end
end
