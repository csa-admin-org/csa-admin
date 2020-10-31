require 'rails_helper'

describe QRReferenceNumber do
  def instance(invoice_id: 706)
    described_class.new(invoice_id)
  end

  specify '#ref' do
    obj = described_class.new(706)
    expect(obj.ref).to eq '000000000000000000000007068'
  end

  specify '#formatted_ref' do
    obj = described_class.new(706)
    expect(obj.formatted_ref).to eq '00 00000 00000 00000 00000 07068'
  end
end
