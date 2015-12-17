require 'rails_helper'

describe Raiffeisen, :vcr do
  let(:raiffeisen) { Raiffeisen.new }

  specify '#get_isr_data' do
    isr_data = raiffeisen.get_isr_data(:all)
    expect(isr_data).to match(
      [
        { invoice_id: 2,   amount: 1.15,   data: String },
        { invoice_id: 2,   amount: 0.95,   data: String },
        { invoice_id: 706, amount: 123.45, data: String }
      ]
    )
  end
end
