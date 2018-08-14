require 'rails_helper'

describe ISRReferenceNumber do
  before {
    Current.acp.ccp = '01-13734-6'
    Current.acp.isr_identity = '00 11041 90802 41000'
  }

  def generate_isr(invoice_id: 706, amount:)
    described_class.new(invoice_id, amount)
  end

  it 'rounds amount cents' do
    isr = generate_isr(amount: 456.78)
    expect(isr.amount_without_cents).to eq '456'
    expect(isr.amount_cents).to eq '80'

    isr = generate_isr(amount: 123.45)
    expect(isr.amount_without_cents).to eq '123'
    expect(isr.amount_cents).to eq '45'

    isr = generate_isr(amount: 0)
    expect(isr.amount_without_cents).to eq 'XXXX'
    expect(isr.amount_cents).to eq 'XX'
  end

  it 'works with long isr_identity' do
    Current.acp.isr_identity = '00 11041 90802 41000'
    isr = generate_isr(amount: 123.50)

    expect(isr.ref).to eq '00 11041 90802 41000 00000 07064'
    expect(isr.full_ref).to eq '0100000123505>001104190802410000000007064+ 010137346>'
  end

  it 'works with 6 digits isr_identity' do
    Current.acp.isr_identity = '800250'
    isr = generate_isr(amount: 123.45)

    expect(isr.ref).to eq '80 02500 00000 00000 00000 07068'
    expect(isr.full_ref).to eq '0100000123458>800250000000000000000007068+ 010137346>'
  end

  it 'adds zero to middle part of CCP' do
    Current.acp.ccp = '01-9252-0'
    isr = generate_isr(amount: 123.50)

    expect(isr.full_ref).to eq '0100000123505>001104190802410000000007064+ 010092520>'
  end
end
