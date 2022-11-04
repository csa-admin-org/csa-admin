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

  describe 'checksum_digit' do
    def checkum(string)
      described_class.new(string.gsub(/\D/, '').to_i).ref.last.to_i
    end

    specify { expect(checkum('00 11041 90802 41000 00000 0001')).to eq 6 }
    specify { expect(checkum('00 11041 90802 41000 00000 0703')).to eq 0 }
    specify { expect(checkum('00 11041 90802 41000 00000 0704')).to eq 1 }
    specify { expect(checkum('00 11041 90802 41000 00000 0705')).to eq 6 }
    specify { expect(checkum('00 11041 90802 41000 00000 0706')).to eq 4 }
    specify { expect(checkum('00 11041 90802 41000 00000 0707')).to eq 2 }
    specify { expect(checkum('12 00000 00000 23447 89432 1689')).to eq 9 }
    specify { expect(checkum('96 11169 00000 00660 00000 0928')).to eq 4 }
    specify { expect(checkum('210000044000')).to eq 1 }
    specify { expect(checkum('01000162')).to eq 8 }
    specify { expect(checkum('03000162')).to eq 5 }
  end
end
