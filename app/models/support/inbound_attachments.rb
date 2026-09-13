# frozen_string_literal: true

require "base64"
require "nokogiri"

module Support
  class InboundAttachments
    IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/gif image/webp].freeze

    def self.split(raw_attachments, html: nil)
      leftover = []
      cid_blobs = {}
      html = html.to_s
      total = 0

      Array(raw_attachments).each do |raw|
        decoded = decode(raw)
        next unless decoded

        cid = content_id(raw)
        if cid.present? && image?(raw) && html.include?("cid:#{cid}")
          blob = blob_for(decoded, raw)
          cid_blobs[cid] = blob if blob
        else
          leftover << [ decoded, raw ] if within_limit?(decoded, total)
          total += decoded.bytesize
        end
      end

      [ leftover, cid_blobs ]
    end

    def self.rewrite_cids(html, cid_blobs)
      return html if cid_blobs.blank?

      doc = Nokogiri::HTML::DocumentFragment.parse(html)
      doc.css("img[src^='cid:']").each do |img|
        cid = img["src"].to_s.delete_prefix("cid:").delete_prefix("<").delete_suffix(">")
        blob = cid_blobs[cid]
        next unless blob

        img.replace(ActionText::Attachment.from_attachable(blob).to_html)
      end
      doc.to_html
    end

    def self.decode(raw)
      content = raw["Content"].presence
      return if content.blank?
      return if content.bytesize > HasAttachments::MAXIMUM_SIZE * 2
      return if raw["ContentLength"].to_i > HasAttachments::MAXIMUM_SIZE

      decoded = Base64.decode64(content)
      return if decoded.bytesize.zero? || decoded.bytesize > HasAttachments::MAXIMUM_SIZE

      decoded
    end
    private_class_method :decode

    def self.content_id(raw)
      raw["ContentID"].to_s.delete("<>").presence
    end
    private_class_method :content_id

    def self.image?(raw)
      IMAGE_TYPES.include?(raw["ContentType"].to_s.downcase.split(";").first)
    end
    private_class_method :image?

    def self.within_limit?(decoded, total)
      total + decoded.bytesize <= HasAttachments::MAXIMUM_SIZE
    end
    private_class_method :within_limit?

    def self.blob_for(decoded, raw)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(decoded),
        filename: raw["Name"].presence || "image",
        content_type: raw["ContentType"].presence || "image/jpeg")
    end
    private_class_method :blob_for
  end
end
