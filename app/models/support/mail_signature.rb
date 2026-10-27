# frozen_string_literal: true

require "nokogiri"

module Support
  # Client signatures, not the operator ++ sign-off. Gmail and Infomaniak
  # mark the block. Render drops data attributes, so a trailing block of
  # signature images is the same footer. A line that is exactly "-- " is
  # the RFC 3676 delimiter: everything after it is the signature.
  class MailSignature
    CSS = ".gmail_signature, .gmail_signature_prefix, #Signature, [data-ik-opengraph-ignore]"
    DELIMITER = /\A--[[:space:]]*\z/
    SIGNATURE_IMAGE = %r{workspace\.storage\.infomaniak\.com/signature}i

    def self.strip_fragment!(root)
      return unless root

      root.css(CSS).each(&:remove)
      drop_image_blocks!(root)
      drop_delimiter!(root)
    end

    def self.strip_text(text)
      source = text.to_s
      head, = source.split(/\n--[[:space:]]*\n/, 2)
      return source if head.nil? || head == source || head.blank?

      head.rstrip
    end

    def self.drop_image_blocks!(root)
      return if fenced?(root)

      root.element_children.each { |child| drop_image_blocks!(child) }
      cut_image_block!(root)
    end
    private_class_method :drop_image_blocks!

    def self.cut_image_block!(root)
      last = root.element_children.reverse.find { |node| signature_block?(node) }
      last.remove if last && reply_before?(last)
    end
    private_class_method :cut_image_block!

    def self.signature_block?(node)
      images = node.css("img")
      images.any? && images.all? { |img| signature_image?(img) } && word?(node)
    end
    private_class_method :signature_block?

    def self.signature_image?(img)
      img["src"].to_s.match?(SIGNATURE_IMAGE)
    end
    private_class_method :signature_image?

    def self.reply_before?(node)
      node.xpath("preceding-sibling::*").any? { |sibling| word?(sibling) }
    end
    private_class_method :reply_before?

    def self.word?(node)
      node.text.gsub(/[[:space:]]/, "").present?
    end
    private_class_method :word?

    def self.drop_delimiter!(root)
      return if fenced?(root)

      root.element_children.each { |child| drop_delimiter!(child) }
      cut_delimiter!(content_children(root))
    end
    private_class_method :drop_delimiter!

    def self.cut_delimiter!(children)
      index = children.rindex { |node| delimiter?(node) }
      return unless index&.positive?
      return if following_content?(children, index) && !spaced?(children[index])

      children[index..].each(&:remove)
    end
    private_class_method :cut_delimiter!

    def self.fenced?(root)
      root.element? && %w[pre code].include?(root.name)
    end
    private_class_method :fenced?

    def self.delimiter?(node)
      node.element? && node.text.match?(DELIMITER) && node.css("img, a").empty?
    end
    private_class_method :delimiter?

    def self.spaced?(node)
      node.text.match?(/\A--[[:space:]]+\z/)
    end
    private_class_method :spaced?

    def self.following_content?(children, index)
      children[(index + 1)..].any? { |node| node.text.match?(/\S/) }
    end
    private_class_method :following_content?

    def self.content_children(root)
      root.children.reject { |node|
        node.comment? || (node.text? && node.content.blank?)
      }
    end
    private_class_method :content_children
  end
end
