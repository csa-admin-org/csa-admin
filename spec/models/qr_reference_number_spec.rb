require 'rails_helper'

describe QRReferenceNumber do
  def instance(invoice_id: 706)
    described_class.new(invoice_id)
  end

  context 'with no bank reference' do
    before { Current.acp.update!(qr_bank_reference: '') }

    specify '#ref' do
      obj = described_class.new(706)
      expect(obj.ref).to eq '000000000000000000000007068'
    end

    specify '#formatted_ref' do
      obj = described_class.new(42)
      expect(obj.formatted_ref).to eq '00 00000 00000 00000 00000 00420'
    end
  end

  context 'with a bank reference' do
    before { Current.acp.update!(qr_bank_reference: 123456) }

    specify '#ref' do
      obj = described_class.new(706)
      expect(obj.ref).to eq '123456000000000000000007069'
    end

    specify '#formatted_ref' do
      obj = described_class.new(42)
      expect(obj.formatted_ref).to eq '12 34560 00000 00000 00000 00429'
    end
  end
end
