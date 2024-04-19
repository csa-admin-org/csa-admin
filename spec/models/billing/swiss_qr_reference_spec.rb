require "rails_helper"

describe Billing::SwissQRReference do
  def ref(member_id = 42, invoice_id = 706)
    invoice = Invoice.new(id: invoice_id, member_id: member_id)
    described_class.new(invoice)
  end

  specify "with no bank reference" do
    Current.acp.update!(bank_reference: "")

    expect(ref.to_s).to eq "000000000000000420000007068"
    expect(ref.formatted).to eq "00 00000 00000 00042 00000 07068"

    expect(described_class.valid?(ref.to_s)).to eq true
    expect(described_class.valid?(ref.formatted)).to eq true

    expect(described_class.payload(ref.formatted)).to eq(
      member_id: 42,
      invoice_id: 706)
  end

  specify "with a bank reference" do
    Current.acp.update!(bank_reference: 123456)

    expect(ref.to_s).to eq "123456000000000420000007063"
    expect(ref.formatted).to eq "12 34560 00000 00042 00000 07063"

    expect(described_class.valid?(ref.to_s)).to eq true
    expect(described_class.valid?(ref.formatted)).to eq true

    expect(described_class.payload(ref.formatted)).to eq(
      member_id: 42,
      invoice_id: 706)
  end

  describe "checksum_digit" do
    def checkum(member_id, invoice_id)
      obj = ref(
        member_id.gsub(/\D/, "").to_i,
        invoice_id.gsub(/\D/, "").to_i
      ).to_s.last.to_i
    end

    specify { expect(checkum("11041 90802 41000", "00000 0001")).to eq 6 }
    specify { expect(checkum("11041 90802 41000", "00000 0703")).to eq 0 }
    specify { expect(checkum("11041 90802 41000", "00000 0704")).to eq 1 }
    specify { expect(checkum("11041 90802 41000", "00000 0705")).to eq 6 }
    specify { expect(checkum("11041 90802 41000", "00000 0706")).to eq 4 }
    specify { expect(checkum("11041 90802 41000", "00000 0707")).to eq 2 }
    specify { expect(checkum("23447", "12 89432 1689")).to eq 2 }
    specify { expect(checkum("96 11169 00000 00660", "00000 0928")).to eq 4 }
  end
end
