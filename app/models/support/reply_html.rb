# frozen_string_literal: true

require "nokogiri"

module Support
  class ReplyHtml
    MARKER_ID = "csa-admin-reply-above"
    QUOTE_CSS = [
      "blockquote[type='cite']",
      "blockquote.gmail_quote",
      "div.gmail_quote",
      "div.gmail_quote_container",
      "div.yahoo_quoted",
      "#divRplyFwdMsg",
      "div#appendonsend",
      "div.OutlookMessageHeader",
      "blockquote.protonmail_quote",
      "div.protonmail_quote"
    ].join(", ")

    def self.extract(html, keep_cited: false)
      return if html.blank?

      root = document_root(html)
      cut_at_marker!(root)
      if keep_cited
        Support::Signature.strip_fragment!(root)
      else
        root.css(QUOTE_CSS).each(&:remove)
        Support::ReplyQuote.clean_fragment!(root)
      end
      cleaned = root.inner_html.to_s.strip
      cleaned.presence
    end

    def self.present(html)
      return if html.blank?

      root = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      root.css("blockquote.protonmail_quote, div.protonmail_quote").each(&:remove)
      Support::ReplyQuote.drop_separators!(root)
      drop_trailing_break!(root)
      root.inner_html.to_s.strip.presence
    end

    def self.drop_trailing_break!(root)
      node = root.children.reverse.find { |child| child.element? || !child.text.strip.empty? }
      node.remove if node&.name == "br"
    end
    private_class_method :drop_trailing_break!

    def self.document_root(html)
      if html.to_s.match?(/<html[\s>]/i)
        parsed = Nokogiri::HTML(html)
        parsed.at("body") || parsed
      else
        Nokogiri::HTML::DocumentFragment.parse(html)
      end
    end
    private_class_method :document_root

    def self.cut_at_marker!(root)
      marker = root.at_css("##{MARKER_ID}")
      return unless marker

      node = marker
      loop do
        while (sibling = node.next_sibling)
          sibling.remove
        end
        parent = node.parent
        break unless parent && parent != root && !root.children.include?(parent)

        node = parent
      end
      marker.remove
    end
    private_class_method :cut_at_marker!
  end
end
