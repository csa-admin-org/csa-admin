# frozen_string_literal: true

require "test_helper"

class AnonymizedDumpIbanTest < ActiveSupport::TestCase
  test "compose matches the ISO 13616 Swiss example" do
    assert_equal "CH9300762011623852957",
      AnonymizedDump::IBAN.compose("CH", "00762011623852957")
  end

  test "generated ibans are valid and stable" do
    swiss = AnonymizedDump::IBAN.generate(country: "CH", seed: 42)
    german = AnonymizedDump::IBAN.generate(country: "DE", seed: 7)
    dutch = AnonymizedDump::IBAN.generate(country: "NL", seed: 3)

    assert AnonymizedDump::IBAN.valid?(swiss)
    assert AnonymizedDump::IBAN.valid?(german)
    assert AnonymizedDump::IBAN.valid?(dutch)
    assert_equal swiss, AnonymizedDump::IBAN.generate(country: "CH", seed: 42)
    assert_equal "DE", german[0, 2]
    assert_equal 18, dutch.length
  end

  test "replace rewrites compact and grouped ibans" do
    compact = AnonymizedDump::IBAN.replace("Pay CH9300762011623852957 thanks", with: "REPLACED")
    grouped = AnonymizedDump::IBAN.replace("IBAN CH93 0076 2011 6238 5295 7 end", with: "REPLACED")

    assert_equal "Pay REPLACED thanks", compact
    assert_equal "IBAN REPLACED end", grouped
  end
end
