# frozen_string_literal: true

require "test_helper"

class ActiveStorage::BlobSignedIdTest < ActiveSupport::TestCase
  setup do
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("invoice"),
      filename: "invoice.pdf",
      content_type: "application/pdf")
  end

  test "a signed id from this tenant does not resolve under another tenant" do
    signed_id = @blob.signed_id

    assert_equal @blob, ActiveStorage::Blob.find_signed(signed_id)

    with_tenant("beta") do
      assert_nil ActiveStorage::Blob.find_signed(signed_id)
      assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
        ActiveStorage::Blob.find_signed!(signed_id)
      end
    end
  end

  test "a legacy signature is rejected for a file that is not only an inline image" do
    legacy = legacy_signed_id(@blob)

    assert_nil ActiveStorage::Blob.find_signed(legacy)
    attach_to_rich_text(@blob)
    ActiveStorage::Attachment.create!(
      name: "file",
      record: members(:john),
      blob: @blob)

    assert_nil ActiveStorage::Blob.find_signed(legacy)
  end

  test "a legacy signature still opens an inline image" do
    attach_to_rich_text(@blob)
    legacy = legacy_signed_id(@blob)

    assert_equal @blob, ActiveStorage::Blob.find_signed(legacy)
    assert_equal @blob, ActiveStorage::Blob.find_signed!(legacy)
  end

  test "a legacy signature is rejected when the newsletter attachment row is gone" do
    record = attach_to_newsletter(@blob)
    legacy = legacy_signed_id(@blob)
    record.delete

    assert_nil ActiveStorage::Blob.find_signed(legacy)
  end

  test "a legacy signature still opens a newsletter file" do
    attach_to_newsletter(@blob)
    legacy = legacy_signed_id(@blob)

    assert_equal @blob, ActiveStorage::Blob.find_signed(legacy)
  end

  test "signing outside a tenant raises" do
    Tenant.disconnect

    error = assert_raises(ArgumentError) { @blob.signed_id }
    assert_match "outside a tenant", error.message
    assert_nil ActiveStorage::Blob.find_signed("not-a-signed-id")
  end

  private

  def legacy_signed_id(blob)
    ActiveStorage::Blob.signed_id_verifier.generate(blob.id, purpose: "blob_id")
  end

  def attach_to_newsletter(blob)
    newsletter = create_newsletter(
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Field report</p>" }
      })
    record = ::Attachment.new(attachable: newsletter)
    record.save!(validate: false)
    ActiveStorage::Attachment.create!(name: "file", record: record, blob: blob)
    record
  end

  def attach_to_rich_text(blob)
    newsletter = create_newsletter(
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "<p>Field report</p>" }
      })
    block = newsletter.association(:blocks).load_target.first
    rich_text = ActionText::RichText.find_by!(record: block, name: "content_en")
    ActiveStorage::Attachment.create!(name: "embeds", record: rich_text, blob: blob)
  end
end
