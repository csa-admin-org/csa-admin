require 'rails_helper'

describe Raiffeisen, :vcr do
  let(:raiffeisen) { Raiffeisen.new }

  specify '#get_isr_data' do
    isr_data = raiffeisen.get_isr_data(:all)
    expect(isr_data).to include(
      invoice_id: 143,
      amount: 1075.0,
      data: start_with('0020101373460011041908024100000000014380000107500999')
    )
    expect(isr_data.size).to eq 88
  end
end
