require "rails_helper"

describe Billing::CamtFile do
  describe "#payments_data" do
    it "returns payment data from CAMT file" do
      file = described_class.new(file_fixture("camt054.xml"))
      expect(file.payments_data).to eq([
        Billing::CamtFile::PaymentData.new(
          invoice_id: 1,
          member_id: 42,
          amount: 1,
          date: Date.new(2020, 11, 13, 11),
          fingerprint: "2020-11-13-ZV20201113/371247/2-000000000000000420000000011")
      ])
    end

    it "returns no payment data when REF has letter" do
      file = described_class.new(file_fixture("camt054_ref_with_letters.xml"))
      expect(file.payments_data).to be_empty
    end

    it "raise for invalid CAMT namespace" do
      file = described_class.new(file_fixture("camt_wrong.xml"))
      expect { file.payments_data }
        .to raise_error(Billing::CamtFile::UnsupportedFileError)
    end

    it "raise for CAMT.053 format" do
      file = described_class.new(file_fixture("camt053.xml"))
      expect { file.payments_data }
        .to raise_error(Billing::CamtFile::UnsupportedFileError)
    end

    it "raise for invalid CAMT file" do
      file = described_class.new(file_fixture("camt_invalid.xml"))
      expect { file.payments_data }
        .to raise_error(Billing::CamtFile::UnsupportedFileError)
    end
  end
end
