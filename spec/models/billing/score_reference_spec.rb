require "rails_helper"

describe Billing::ScorReference do
  def ref(member_id:, invoice_id:)
    invoice = Invoice.new(id: invoice_id, member_id: member_id)
    described_class.new(invoice)
  end

  specify "min ids" do
    ref = ref(member_id: 1, invoice_id: 1)
    expect(ref.to_s).to eq "RF210000000100000001"
    expect(ref.formatted).to eq "RF21 0000 0001 0000 0001"

    expect(described_class.valid?(ref.to_s)).to eq true
    expect(described_class.valid?(ref.formatted)).to eq true

    expect(described_class.payload(ref.formatted)).to eq(
      member_id: 1,
      invoice_id: 1)
  end

  specify "small ids" do
    ref = ref(member_id: 42, invoice_id: 69)
    expect(ref.to_s).to eq "RF860000004200000069"
    expect(ref.formatted).to eq "RF86 0000 0042 0000 0069"

    expect(described_class.valid?(ref.to_s)).to eq true
    expect(described_class.valid?(ref.formatted)).to eq true

    expect(described_class.payload(ref.formatted)).to eq(
      member_id: 42,
      invoice_id: 69)
  end

  specify "max ids" do
    ref = ref(member_id: 99_999_999, invoice_id: 99_999_999)
    expect(ref.to_s).to eq "RF069999999999999999"
    expect(ref.formatted).to eq "RF06 9999 9999 9999 9999"

    expect(described_class.valid?(ref.to_s)).to eq true
    expect(described_class.valid?(ref.formatted)).to eq true

    expect(described_class.payload(ref.formatted)).to eq(
      member_id: 99_999_999,
      invoice_id: 99_999_999)
  end
end
