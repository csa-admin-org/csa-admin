# frozen_string_literal: true

require "test_helper"

class Billing::ScorReferenceTest < ActiveSupport::TestCase
  def ref(member_id:, invoice_id:)
    invoice = Invoice.new(id: invoice_id, member_id: member_id)
    Billing::ScorReference.new(invoice)
  end

  test "min ids" do
    ref = ref(member_id: 1, invoice_id: 1)
    assert_equal "RF210000000100000001", ref.to_s
    assert_equal "RF21 0000 0001 0000 0001", ref.formatted

    assert Billing::ScorReference.valid?(ref.to_s)
    assert Billing::ScorReference.valid?(ref.formatted)

    assert_equal({ member_id: 1, invoice_id: 1 }, Billing::ScorReference.payload(ref.formatted))
  end

  test "small ids" do
    ref = ref(member_id: 42, invoice_id: 69)
    assert_equal "RF860000004200000069", ref.to_s
    assert_equal "RF86 0000 0042 0000 0069", ref.formatted

    assert Billing::ScorReference.valid?(ref.to_s)
    assert Billing::ScorReference.valid?(ref.formatted)

    assert_equal({ member_id: 42, invoice_id: 69 }, Billing::ScorReference.payload(ref.formatted))
  end

  test "max ids" do
    ref = ref(member_id: 99_999_999, invoice_id: 99_999_999)
    assert_equal "RF069999999999999999", ref.to_s
    assert_equal "RF06 9999 9999 9999 9999", ref.formatted

    assert Billing::ScorReference.valid?(ref.to_s)
    assert Billing::ScorReference.valid?(ref.formatted)

    assert_equal({ member_id: 99_999_999, invoice_id: 99_999_999 }, Billing::ScorReference.payload(ref.formatted))
  end

  test "with non-word character after" do
    ref = "RF.86-0000@0042*0000(0069)"

    assert Billing::ScorReference.valid?(ref)
    assert_equal({ member_id: 42, invoice_id: 69 }, Billing::ScorReference.payload(ref))
  end

  test "with random text after" do
    ref = "RF86 0000 0042 0000 0069 von John Doe"

    assert Billing::ScorReference.valid?(ref)
    assert_equal({ member_id: 42, invoice_id: 69 }, Billing::ScorReference.payload(ref))
  end

  test "with random text before" do
    ref = "EREF:  RF860000004200000069"

    assert Billing::ScorReference.valid?(ref)
    assert_equal({ member_id: 42, invoice_id: 69 }, Billing::ScorReference.payload(ref))
  end

  test "with multiple ref (takes first)" do
    ref = "RF86 0000 0042 0000 0069/RF86 0000 0042 0000 0071"

    assert Billing::ScorReference.valid?(ref)
    assert_equal({ member_id: 42, invoice_id: 69 }, Billing::ScorReference.payload(ref))
  end

  test "valid? with checksum invalid" do
    assert Billing::ScorReference.valid?("RF19 0000 0109 0000 0116")
    assert_not Billing::ScorReference.valid?("RF14 0000 0109 0000 0116")
    assert_not Billing::ScorReference.valid?("RF19 0000 0109 0000 011")
    assert_not Billing::ScorReference.valid?("FOO")
    assert_not Billing::ScorReference.valid?("TAN1: SecureGo plus")
  end
end
