# frozen_string_literal: true

require "test_helper"

class Support::ReplyBodyTest < ActiveSupport::TestCase
  test "prefers stripped reply" do
    assert_equal "My answer", Support::ReplyBody.extract(
      text_body: "My answer\n\nOn Mon, Jane wrote:\nHello",
      stripped: "My answer")
  end

  test "falls back to text before quote" do
    body = Support::ReplyBody.extract(
      text_body: "My answer\n\nOn Mon, Jane wrote:\nHello",
      stripped: nil)

    assert_equal "My answer", body
  end

  test "splits french quote" do
    body = Support::ReplyBody.extract(
      text_body: "Oui\n\nLe lundi, Pierre a écrit :\nBonjour",
      stripped: "")

    assert_equal "Oui", body
  end

  test "splits apple mail hat geschrieben leftover" do
    body = Support::ReplyBody.extract(
      text_body: <<~TEXT,
        I am changing now all the cycles again.

        Am Dienstag, 6. Januar 2026 um 09:30:31 +01:00, hat <info@grundnahrig.ch> geschrieben:
        ah and i already received 2 emails
      TEXT
      stripped: "")

    assert_equal "I am changing now all the cycles again.", body
  end

  test "splits a glued hat geschrieben leftover" do
    body = Support::ReplyBody.extract(
      text_body: "Own hop\n\nAm Dienstag, 6. Januar 2026 um 09:16:06 +01:00, hat <info@grundnahrig.ch> geschrieben:hey Thibaud",
      stripped: "")

    assert_equal "Own hop", body
  end

  test "original_from reads quoted address" do
    text = "Answer\n\nOn Mon, Jane Doe <jane@org.ch> wrote:\nHello"
    assert_equal "jane@org.ch", Support::ReplyBody.original_from(text)
  end

  test "cuts at the wrap marker" do
    body = Support::ReplyBody.extract(
      text_body: "My answer\nCSA-ADMIN-REPLY-ABOVE\nquoted stuff",
      stripped: nil)

    assert_equal "My answer", body
  end

  test "strips trailing markdown quotes left in stripped reply" do
    body = Support::ReplyBody.extract(
      text_body: nil,
      stripped: "Merci :)\n\n> On Mon, Jane wrote:\n> Hello")

    assert_equal "Merci :)", body
  end

  test "cuts wrap-shaped payload at the marker and drops the quoted previous" do
    body = Support::ReplyBody.extract(
      text_body: "My answer\nCSA-ADMIN-REPLY-ABOVE\nJane, 13 Sep:\n> old thread",
      stripped: nil)

    assert_equal "My answer", body
  end

  test "keep_cited wraps the quoted original as markdown" do
    body = Support::ReplyBody.extract(
      text_body: "Here is the answer\n\nOn Mon, Jane Doe <jane@org.ch> wrote:\nHello",
      stripped: "Here is the answer",
      keep_cited: true)

    assert_includes body, "Here is the answer"
    assert_includes body, "> On Mon, Jane Doe <jane@org.ch> wrote:"
    assert_includes body, "> Hello"
  end

  test "strips a trailing operator signature" do
    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      body = Support::ReplyBody.extract(
        text_body: "Voici\n\n++\nThibaud\n\nLe lundi, Jane a écrit :\nquoted",
        stripped: nil)

      assert_equal "Voici", body
    end
  end
end
