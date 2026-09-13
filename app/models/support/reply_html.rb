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
      "div.OutlookMessageHeader"
    ].join(", ")

    def self.extract(html)
      return if html.blank?

      root = document_root(html)
      cut_at_marker!(root)
      root.css(QUOTE_CSS).each(&:remove)
      Support::ReplyQuote.clean_fragment!(root)
      cleaned = root.inner_html.to_s.strip
      cleaned.presence
    end

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
