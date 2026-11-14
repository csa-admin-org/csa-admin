# frozen_string_literal: true

# Blob signed ids sign only the row id with the app-wide secret. Each tenant
# has its own integer sequence, so an id minted on one host verified on every
# other host and served that tenant's file. New signatures include the tenant.
#
# Old signatures stay valid only for inline images and newsletter files.
# An invoice, mandate, or other file with the old purpose is rejected.
# A blob attached to both a newsletter and an invoice is rejected too.
module ActiveStorageBlobTenantSignedId
  LEGACY_PURPOSE = "blob_id"
  LEGACY_PUBLIC_RECORD_TYPES = %w[ActionText::RichText Attachment].freeze

  def signed_id(...)
    raise ArgumentError, "Cannot sign an Active Storage blob outside a tenant" if Tenant.outside?

    super
  end

  module ClassMethods
    def find_signed(signed_id, ...)
      super || legacy_public_blob(signed_id)
    end

    def find_signed!(signed_id, ...)
      super
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      legacy_public_blob(signed_id) || raise
    end

    def combine_signed_id_purposes(purpose)
      "#{Tenant.current}/#{purpose}"
    end

    private

    def legacy_public_blob(signed_id)
      return if Tenant.outside?

      id = signed_id_verifier.verified(signed_id, purpose: LEGACY_PURPOSE)
      return unless id && (blob = find_by(id: id))
      return unless legacy_public?(blob)

      blob
    end

    def legacy_public?(blob)
      grouped = blob.attachments.pluck(:record_type, :record_id).group_by(&:first)
      return false if grouped.empty?
      return false if (grouped.keys - LEGACY_PUBLIC_RECORD_TYPES).any?
      return true unless grouped["Attachment"]

      ids = grouped["Attachment"].map(&:last).uniq
      ::Attachment.where(id: ids, attachable_type: "Newsletter").count == ids.size
    end
  end
end

# after_initialize: ActiveStorage::Blob is not loaded while initializers run.
Rails.application.config.after_initialize do
  ActiveStorage::Blob.prepend(ActiveStorageBlobTenantSignedId)
  ActiveStorage::Blob.singleton_class.prepend(ActiveStorageBlobTenantSignedId::ClassMethods)
end
