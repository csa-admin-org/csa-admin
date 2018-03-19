require 'rails_helper'

describe Billing::Raiffeisen, :vcr do
  let(:raiffeisen) { Billing::Raiffeisen.new(Current.acp.credentials(:raiffeisen)) }

  specify '#payments_data' do
    payments_data = raiffeisen.payments_data
    expect(payments_data).to include(
      Billing::Raiffeisen::PaymentData.new(
        invoice_id: 143,
        amount: BigDecimal(1075),
        date: Date.new(2016, 2, 29),
        isr_data: '0-00201013734600110419080241000000000143800001075009999999916022916022916022999999999500000000000000'),
      Billing::Raiffeisen::PaymentData.new(
        invoice_id: 272,
        amount: BigDecimal(955),
        date: Date.new(2016, 2, 29),
        isr_data: '7-00201013734600110419080241000000000272600000955009999999916022916022916022999999999500000000000000')
    )
    invoice_ids = payments_data.map { |i| i.invoice_id }
    expect(invoice_ids).not_to include(999999999999)
    expect(payments_data.size).to eq 90
  end
end
