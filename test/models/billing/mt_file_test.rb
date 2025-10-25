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
        amount: 285.00,
        date: Date.new(2024, 4, 3),
        origin: "mt940")
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
        origin: "mt940")
    ], file.payments_data
  end

  test "handle reversal credit with negative payment" do
    file = Billing::MtFile.new(file_fixture("mt940-reversal.mta"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 1,
        amount: -285.00,
        date: Date.new(2024, 4, 3),
        origin: "mt940")
    ], file.payments_data
  end

  test "raises for CAMT file" do
    file = Billing::MtFile.new(file_fixture("camt053.xml"))
    assert_raises(Billing::MtFile::UnsupportedFileError) do
      file.payments_data
    end
  end

  test "raises for other file format" do
    file = Billing::MtFile.new(file_fixture("logo.png"))
    assert_raises(Billing::MtFile::UnsupportedFileError) do
      file.payments_data
    end
  end
end
