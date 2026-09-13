# frozen_string_literal: true

require "test_helper"

class Support::SignatureTest < ActiveSupport::TestCase
  setup { @name = { "ULTRA_ADMIN_NAME" => "Thibaud" } }

  test "strips a trailing plus-plus signature from text" do
    with_env(@name) do
      assert_equal "Voici", Support::Signature.strip_text("Voici\n\n++\nThibaud")
    end
  end

  test "strips a trailing dash signature from text" do
    with_env(@name) do
      assert_equal "Voici", Support::Signature.strip_text("Voici\n\n--\nThibaud")
    end
  end

  test "leaves mid-body plus-plus alone" do
    with_env(@name) do
      text = "Use ++ for plus\nThibaud said no"
      assert_equal text, Support::Signature.strip_text(text)
    end
  end

  test "is a no-op without ULTRA_ADMIN_NAME" do
    with_env("ULTRA_ADMIN_NAME" => nil) do
      text = "Voici\n\n++\nThibaud"
      assert_equal text, Support::Signature.strip_text(text)
    end
  end

  test "strips two paragraph apple mail signature" do
    with_env(@name) do
      html = "<p>Voici</p><p>++</p><p>Thibaud</p>"
      root = Nokogiri::HTML::DocumentFragment.parse(html)
      Support::Signature.strip_fragment!(root)

      assert_includes root.to_html, "Voici"
      assert_not_includes root.to_html, "++"
      assert_not_includes root.to_html, "Thibaud"
    end
  end

  test "strips a combined signature paragraph" do
    with_env(@name) do
      html = "<p>Voici</p><p>++<br>Thibaud</p>"
      root = Nokogiri::HTML::DocumentFragment.parse(html)
      Support::Signature.strip_fragment!(root)

      assert_includes root.to_html, "Voici"
      assert_not_includes root.to_html, "++"
      assert_not_includes root.to_html, "Thibaud"
    end
  end

  test "appends plus-plus to text once" do
    with_env(@name) do
      signed = Support::Signature.append_text("Voici")

      assert_equal "Voici\n\n++\nThibaud", signed
      assert_equal signed, Support::Signature.append_text(signed)
    end
  end

  test "appends plus-plus paragraphs to html once" do
    with_env(@name) do
      signed = Support::Signature.append_html("<p>Voici</p>")

      assert_includes signed, "<p>Voici</p>"
      assert_includes signed, "<p>++<br>Thibaud</p>"
      assert_equal signed, Support::Signature.append_html(signed)
    end
  end
end
