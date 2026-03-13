# frozen_string_literal: true

require "test_helper"

class Organization::LogoTest < ActiveSupport::TestCase
  test "accepts a valid square PNG logo" do
    Current.org.logo.attach(
      io: file_fixture("logo-valid.png").open,
      filename: "logo.png",
      content_type: "image/png")

    assert Current.org.valid?
  end

  test "accepts a valid square JPEG logo" do
    Current.org.logo.attach(
      io: file_fixture("logo-valid.png").open,
      filename: "logo.jpg",
      content_type: "image/jpeg")

    assert Current.org.valid?
  end

  test "rejects non-image content type" do
    Current.org.logo.attach(
      io: file_fixture("invoice.pdf").open,
      filename: "logo.pdf",
      content_type: "application/pdf")

    assert_not Current.org.valid?
    assert_includes Current.org.errors[:logo], "must be a PNG or JPEG image"
  end

  test "rejects logo heavier than 400 KB" do
    Current.org.logo.attach(
      io: StringIO.new("x" * (400.kilobytes + 1)),
      filename: "big.png",
      content_type: "image/png")

    assert_not Current.org.valid?
    assert_includes Current.org.errors[:logo], "must be less than 400 KB"
  end

  test "rejects non-square logo" do
    Current.org.logo.attach(
      io: file_fixture("logo-not-square.png").open,
      filename: "logo.png",
      content_type: "image/png")

    assert_not Current.org.valid?
    assert_includes Current.org.errors[:logo], "must be square"
  end

  test "rejects logo smaller than 512x512" do
    Current.org.logo.attach(
      io: file_fixture("logo-too-small.png").open,
      filename: "logo.png",
      content_type: "image/png")

    assert_not Current.org.valid?
    assert_includes Current.org.errors[:logo], "must be at least 512×512 pixels"
  end

  test "optimizes logo on save" do
    original_data = file_fixture("logo-valid.png").read
    Current.org.logo.attach(
      io: StringIO.new(original_data),
      filename: "logo.png",
      content_type: "image/png")
    Current.org.save!

    assert Current.org.logo.blob.byte_size <= original_data.bytesize
  end

  test "does not validate logo when no new blob is attached" do
    assert Current.org.valid?
  end
end
