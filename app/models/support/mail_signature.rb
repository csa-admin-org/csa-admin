# frozen_string_literal: true

require "nokogiri"

module Support
  # Client signatures, not the operator ++ sign-off. Gmail marks the block.
  # A line that is exactly "-- " is the RFC 3676 delimiter: everything after
  # it is the signature. A bare "--" only counts when nothing follows.
  class MailSignature
    CSS = ".gmail_signature, .gmail_signature_prefix, #Signature"
    DELIMITER = /\A--[[:space:]]*\z/

    def self.strip_fragment!(root)
      return unless root

      root.css(CSS).each(&:remove)
      drop_delimiter!(root)
    end

    def self.strip_text(text)
      source = text.to_s
      head, = source.split(/\n--[[:space:]]*\n/, 2)
      return source if head.nil? || head == source || head.blank?

      head.rstrip
    end

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
