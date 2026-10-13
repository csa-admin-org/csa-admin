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
      "div.gmail_attr",
      "div.moz-cite-prefix",
      "pre.moz-cite-prefix",
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
      strip_styles!(root)
      cleaned = root.inner_html.to_s.strip
      cleaned.presence
    end

    def self.split_cited(html)
      return [ nil, nil ] if html.blank?

      root = document_root(html)
      cut_at_marker!(root)
      original = extract_cited!(root)
      drop_header_only_cites!(root)
      Support::Signature.strip_fragment!(root)
      strip_styles!(root)
      return [ root.inner_html.to_s.strip.presence, nil ] if original.blank?

      unwrap_cite!(original)
      drop_cite_headers!(original)
      unwrap_cite!(original)
      strip_styles!(original)
      original_html = original.inner_html.to_s.strip.presence
      original_html = nil if original_html && blank_cited?(original)
      [ root.inner_html.to_s.strip.presence, original_html ]
    end

    def self.present(html)
      return if html.blank?

      root = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      root.css("blockquote.protonmail_quote, div.protonmail_quote").each(&:remove)
      Support::ReplyQuote.drop_separators!(root)
      drop_trailing_break!(root)
      strip_styles!(root)
      root.inner_html.to_s.strip.presence
    end

    def self.strip_styles(html)
      return html if html.blank?

      root = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      strip_styles!(root)
      root.to_html.html_safe
    end

    SKIP_STYLE = %w[pre code img figure action-text-attachment].freeze
    private_constant :SKIP_STYLE

    def self.strip_styles!(root)
      styled = root.css("[style]")
      styled = [ root, *styled ] if root.element? && root["style"].present?
      styled.each do |node|
        next if skip_style?(node)

        node.remove_attribute("style")
      end
    end
    private_class_method :strip_styles!

    def self.skip_style?(node)
      SKIP_STYLE.include?(node.name) ||
        node.ancestors.any? { |ancestor| SKIP_STYLE.include?(ancestor.name) }
    end
    private_class_method :skip_style?

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

    def self.extract_cited!(root)
      cited = cited_node(root)
      return unless cited

      fragment = Nokogiri::HTML::DocumentFragment.parse("")
      node = cited
      while node
        nxt = node.next_sibling
        fragment.add_child(node)
        node = nxt
      end
      fragment
    end
    private_class_method :extract_cited!

    def self.cited_node(root)
      cited = root.at_css(QUOTE_CSS) || split_children(root).find { |node| cite_header?(node) }
      return unless cited

      start = cited
      while start.parent && start.parent != root && !later_meaningful?(start)
        start = start.parent
      end
      start
    end
    private_class_method :cited_node

    def self.later_meaningful?(node)
      sib = node.next_sibling
      while sib
        return true unless blank_node?(sib)

        sib = sib.next_sibling
      end
      false
    end
    private_class_method :later_meaningful?

    def self.drop_header_only_cites!(root)
      root.css(QUOTE_CSS).each do |node|
        node.remove if header_only_node?(node)
      end
    end
    private_class_method :drop_header_only_cites!

    def self.header_only_node?(node)
      sample = Nokogiri::HTML::DocumentFragment.parse(node.to_html)
      unwrap_cite!(sample)
      drop_cite_headers!(sample)
      blank_cited?(sample)
    end
    private_class_method :header_only_node?

    def self.blank_cited?(node)
      node.text.to_s.gsub(/[[:space:]]+/, "").blank? &&
        node.css("img, action-text-attachment, figure").empty?
    end
    private_class_method :blank_cited?

    def self.unwrap_cite!(root)
      loop do
        children = split_children(root)
        break unless children.size == 1 && cite_wrapper?(children.first)

        children.first.replace(children.first.children)
      end
    end
    private_class_method :unwrap_cite!

    def self.drop_cite_headers!(root)
      loop do
        children = split_children(root)
        break if children.empty?

        first = children.first
        if wrapper?(first) && split_children(first).size <= 1
          before = first.inner_html
          drop_cite_headers!(first)
          first.remove if blank_node?(first) || split_children(first).empty?
          break if first.parent && first.inner_html == before
          next
        end
        break unless droppable_header?(first)

        first.remove
      end
    end
    private_class_method :drop_cite_headers!

    def self.cite_wrapper?(node)
      node.element? && (node.name == "blockquote" || node.matches?(QUOTE_CSS))
    end
    private_class_method :cite_wrapper?

    def self.droppable_header?(node)
      return true if node.element? && node.matches?(QUOTE_CSS) && split_children(node).empty?

      cite_header?(node)
    end
    private_class_method :droppable_header?

    def self.cite_header?(node)
      core = node.text.to_s.gsub(/[[:space:]]+/, " ").strip
      return false if core.blank?
      return true if header_only?(core, Support::ReplyQuote::ATTRIBUTION)
      return true if header_only?(core, Support::ReplyBody::QUOTE_SPLIT)

      core.length < 180 && core.match?(/\A#{Support::ForwardedQuote::HEADER_LABEL.source}\s*:/i)
    end
    private_class_method :cite_header?

    def self.header_only?(text, pattern)
      match = text.match(pattern) || "\n#{text}".match(pattern)
      match && match.post_match.to_s.gsub(/[[:punct:][:space:]]/, "").blank?
    end
    private_class_method :header_only?

    def self.wrapper?(node)
      node.element? && %w[div span p].include?(node.name)
    end
    private_class_method :wrapper?

    def self.blank_node?(node)
      return true if node.text? && node.content.blank?
      return true if node.element? && node.name == "br"
      return false unless node.element?
      return false if %w[img action-text-attachment figure].include?(node.name)

      node.text.to_s.strip.blank? &&
        node.css("img, action-text-attachment, figure").empty?
    end
    private_class_method :blank_node?

    def self.split_children(root)
      root.children.reject { |node|
        node.comment? || (node.text? && node.content.blank?)
      }
    end
    private_class_method :split_children
  end
end
