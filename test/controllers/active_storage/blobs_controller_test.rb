# frozen_string_literal: true

require "test_helper"

class ActiveStorage::BlobsControllerTest < ActionDispatch::IntegrationTest
  test "a signed blob url from one tenant is not served on another" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("mandate"),
      filename: "mandate.pdf",
      content_type: "application/pdf")
    path = rails_blob_path(blob, disposition: "attachment")

    host! "admin.acme.test"
    get path
    assert_response :redirect

    # Production requests start outside a tenant. The test helper stays on acme,
    # which makes Tenant.switch to beta illegal.
    Tenant.disconnect
    host! "admin.beta.test"
    get path
    assert_response :not_found
  end
end
