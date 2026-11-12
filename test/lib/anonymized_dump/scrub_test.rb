# frozen_string_literal: true

require "test_helper"

class AnonymizedDumpScrubTest < ActiveSupport::TestCase
  test "strips signed ids and active storage urls" do
    cleaned = AnonymizedDump::Scrub.strip_signed_ids(
      "attachments" => [ { "signed_id" => "abc", "filename" => "a.pdf" } ])
    text = AnonymizedDump::Scrub.text(
      'see /rails/active_storage/blobs/redirect/secret and <img sgid="token">',
      iban: "[iban]")

    assert_equal [ { "filename" => "a.pdf" } ], cleaned["attachments"]
    assert_not_includes text, "/rails/active_storage/"
    assert_includes text, 'sgid=""'
  end
end
