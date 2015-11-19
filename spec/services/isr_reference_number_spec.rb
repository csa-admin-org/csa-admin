require 'rails_helper'

describe ISRReferenceNumber do
  let(:isr) { described_class.new(invoice_id, amount) }
  let(:amount) { 123.45 }
  let(:invoice_id) { 706 }

  specify { expect(isr.ref).to eq '00 11041 90802 41000 00000 07064' }
  specify do
    expect(isr.full_ref)
      .to eq '0100000123458>001104190802410000000007064+ 01137346>'
  end

  context 'with not rounded amount' do
    let(:amount) { 456.78 }

    specify do
      expect(isr.full_ref)
        .to eq '0100000456807>001104190802410000000007064+ 01137346>'
    end
  end
end
