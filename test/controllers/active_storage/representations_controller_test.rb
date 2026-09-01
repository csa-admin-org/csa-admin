# frozen_string_literal: true

require "test_helper"

class ActiveStorage::RepresentationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  test "returns not found when the blob is not a loadable image" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("not an image"),
      filename: "broken.png",
      content_type: "image/png")

    get newsletter_representation_path(blob)

    assert_response :not_found
  end

  test "redirects a valid image representation to the storage service" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo.png").open,
      filename: "logo.png",
      content_type: "image/png")

    get newsletter_representation_path(blob)

    assert_redirected_to %r{\Ahttp://admin\.acme\.test/rails/active_storage/disk/}
  end

  private

  # Same JPEG variant as app/views/active_storage/blobs/_blob.html.erb
  # (newsletter / Trix attachments).
  def newsletter_representation_path(blob)
    rails_representation_path(
      blob.representation(
        resize_to_limit: [ 1024, 768 ],
        format: :jpeg,
        saver: { quality: 80, background: [ 255, 255, 255 ] }))
  end
end
