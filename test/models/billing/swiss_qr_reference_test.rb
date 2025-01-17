# frozen_string_literal: true

require "test_helper"

class Billing::SwissQRReferenceTest < ActiveSupport::TestCase
  def ref(member_id = 42, invoice_id = 706)
    invoice = Invoice.new(id: invoice_id, member_id: member_id)
    Billing::SwissQRReference.new(invoice)
  end

  test "with no bank reference" do
    org(bank_reference: "")

    assert_equal "000000000000000420000007068", ref.to_s
    assert_equal "00 00000 00000 00042 00000 07068", ref.formatted

    assert Billing::SwissQRReference.valid?(ref.to_s)
    assert Billing::SwissQRReference.valid?(ref.formatted)

    assert_equal({ member_id: 42, invoice_id: 706 }, Billing::SwissQRReference.payload(ref.formatted))
  end

  test "with a bank reference" do
    org(bank_reference: 123456)

    assert_equal "123456000000000420000007063", ref.to_s
    assert_equal "12 34560 00000 00042 00000 07063", ref.formatted

    assert Billing::SwissQRReference.valid?(ref.to_s)
    assert Billing::SwissQRReference.valid?(ref.formatted)

    assert_equal({ member_id: 42, invoice_id: 706 }, Billing::SwissQRReference.payload(ref.formatted))
  end

  def checksum(member_id, invoice_id)
    ref(
      member_id.gsub(/\D/, "").to_i,
      invoice_id.gsub(/\D/, "").to_i
    ).to_s.last.to_i
  end

  test "checksum_digit" do
    assert_equal 6, checksum("11041 90802 41000", "00000 0001")
    assert_equal 0, checksum("11041 90802 41000", "00000 0703")
    assert_equal 1, checksum("11041 90802 41000", "00000 0704")
    assert_equal 6, checksum("11041 90802 41000", "00000 0705")
    assert_equal 4, checksum("11041 90802 41000", "00000 0706")
    assert_equal 2, checksum("11041 90802 41000", "00000 0707")
    assert_equal 2, checksum("23447", "12 89432 1689")
    assert_equal 4, checksum("96 11169 00000 00660", "00000 0928")
  end
end
