# frozen_string_literal: true

require "test_helper"

class Billing::MtFileTest < ActiveSupport::TestCase
  setup do
    org(country_code: "DE", iban: "DE89370400440532013000")
  end

  test "returns payment data from MT940 file (.mta)" do
    file = Billing::MtFile.new(file_fixture("mt940.mta"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 1,
        amount: 285.0,
        date: Date.new(2024, 4, 3),
        fingerprint: "2024-04-03-afe4bf1b6077d100c590715c722231a81ea521d7ab70039f7a3c657a2a5f5c9d-RF210000000100000001"
      )
    ], file.payments_data
  end

  test "returns payment data from MT940 file (.mt9)" do
    org(bank_reference: "398834", country_code: "CH")
    file = Billing::MtFile.new(file_fixture("mt940.mt9"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 29,
        member_id: 29,
        amount: 50.0,
        date: Date.new(2025, 1, 3),
        fingerprint: "2025-01-03-fd774b71e31db3d18ac12639f7d3c898544a41fd7b1f26f2b7cdea55193dbd4a-398834000000000290000000293"
      )
    ], file.payments_data
  end

  test "raises for CAMT file" do
    file = Billing::MtFile.new(file_fixture("camt053.xml"))
    assert_raises(Billing::MtFile::UnsupportedFileError, /Wrong line format:.*/) do
      file.payments_data
    end
  end

  test "raises for other file format" do
    file = Billing::MtFile.new(file_fixture("logo.png"))
    assert_raises(Billing::MtFile::UnsupportedFileError, /Wrong line format:.*/) do
      file.payments_data
    end
  end
end
