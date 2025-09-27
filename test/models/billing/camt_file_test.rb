# frozen_string_literal: true

require "test_helper"

class Billing::CamtFileTest < ActiveSupport::TestCase
  test "returns payment data from CAMT.054 file" do
    file = Billing::CamtFile.new(file_fixture("camt054.xml"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 42,
        amount: 1,
        date: Date.new(2020, 11, 13, 11),
        fingerprint: "2020-11-13-ZV20201113/371247/2-000000000000000420000000011"
      )
    ], file.payments_data
  end

  test "returns payment data from CAMT.053 file" do
    org(country_code: "DE")
    file = Billing::CamtFile.new(file_fixture("camt053.xml"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 42,
        amount: 1,
        date: Date.new(2013, 12, 27),
        fingerprint: "2013-12-27-NOBANKREF-RF790000004200000001"
      )
    ], file.payments_data
  end

  test "returns no payment data when REF has letter" do
    file = Billing::CamtFile.new(file_fixture("camt054_ref_with_letters.xml"))
    assert_empty file.payments_data
  end

  test "raises for invalid CAMT namespace" do
    file = Billing::CamtFile.new(file_fixture("camt_wrong.xml"))
    assert_raises(Billing::CamtFile::UnsupportedFileError) { file.payments_data }
  end

  test "raises for invalid CAMT file" do
    file = Billing::CamtFile.new(file_fixture("camt_invalid.xml"))
    assert_raises(Billing::CamtFile::UnsupportedFileError) { file.payments_data }
  end
end
