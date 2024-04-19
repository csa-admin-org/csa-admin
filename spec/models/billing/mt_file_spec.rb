require "rails_helper"

describe Billing::MtFile do
  before do
    Current.acp.update!(
      country_code: "DE",
      iban: "DE89370400440532013000")
  end

  describe "#payments_data" do
    it "returns payment data from MT940 file" do
      file = described_class.new(file_fixture("mt940.mta"))
      expect(file.payments_data).to eq([
        Billing::CamtFile::PaymentData.new(
          invoice_id: 1,
          member_id: 1,
          amount: 285.0,
          date: Date.new(2024, 4, 3),
          fingerprint: "2024-04-03-afe4bf1b6077d100c590715c722231a81ea521d7ab70039f7a3c657a2a5f5c9d-RF210000000100000001")
      ])
    end

    it "raise for CAMT file" do
      file = described_class.new(file_fixture("camt053.xml"))
      expect { file.payments_data }
        .to raise_error(Billing::MtFile::UnsupportedFileError, /Wrong line format:.*/)
    end

    it "raise for other file format" do
      file = described_class.new(file_fixture("logo.png"))
      expect { file.payments_data }
        .to raise_error(Billing::MtFile::UnsupportedFileError, /Wrong line format:.*/)
    end
  end
end
