# frozen_string_literal: true

require "test_helper"

class Query::BlobsControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "streams blob bytes" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "invoice.pdf",
      content_type: "application/pdf")

    query_get "/acme/blobs/#{blob.id}"

    assert_response :success
    assert_equal "%PDF-1.4 test", response.body
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers["Content-Disposition"])
    assert_match(/invoice\.pdf/, response.headers["Content-Disposition"])
  end

  test "missing blob is 404" do
    query_get "/acme/blobs/0"

    assert_response :not_found
    assert_equal "not_found", json_response["error"]
  end

  test "missing file is 404" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("gone"),
      filename: "gone.pdf",
      content_type: "application/pdf")
    blob.service.delete(blob.key)

    query_get "/acme/blobs/#{blob.id}"

    assert_response :not_found
    assert_equal "not_found", json_response["error"]
  end
end
