# frozen_string_literal: true

require "test_helper"

class AnonymizedDumpIdentityTest < ActiveSupport::TestCase
  setup do
    @identity = AnonymizedDump::Identity.new(salt: "test-salt")
  end

  test "names and emails are deterministic per id" do
    first = @identity.person_name("members", 12, "name", "fr")
    again = @identity.person_name("members", 12, "name", "fr")
    other = @identity.person_name("members", 13, "name", "fr")

    assert_equal first, again
    assert_not_equal first, other
    assert_equal "#{I18n.transliterate(first).parameterize(separator: ".")}.12@mailinator.com",
      @identity.email_address(first, 12)
  end

  test "zip and city come from the same place" do
    place = @identity.place("members", 4, "home", "de", "CH")

    assert_includes [ %w[8001 Zürich], %w[3000 Bern], %w[4001 Basel], %w[9000 St. Gallen], %w[6003 Luzern] ],
      [ place.zip, place.city ]
  end

  test "phones follow the country" do
    assert_match(/\A\+4179\d{7}\z/, @identity.phone(country: "CH", seed: 9))
    assert_match(/\A\+49151\d{8}\z/, @identity.phone(country: "DE", seed: 9))
    assert_match(/\A\+316\d{8}\z/, @identity.phone(country: "NL", seed: 9))
  end
end
