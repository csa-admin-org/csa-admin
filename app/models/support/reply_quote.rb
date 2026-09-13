# frozen_string_literal: true

require "nokogiri"

module Support
  class ReplyQuote
    ATTRIBUTION = /\A(?:
      On[[:space:]].+\bwrote: |
      Le[[:space:]].*\d.+\ba[[:space:]]+écrit[[:space:]]*:? |
      \d{1,2}[[:space:]].+\d{4}.+\ba[[:space:]]+écrit[[:space:]]*:? |
      Am[[:space:]].+\bschrieb\.?:? |
      Il[[:space:]]+giorno[[:space:]].+\bha[[:space:]]+scritto:? |
      Op[[:space:]].+\bschreef.+:
    )/ix

    def self.clean_fragment!(root)
      Support::Utf8.repair_fragment!(root)
      cut_quoted_thread!(root)
      drop_trailing!(root)
      Support::Signature.strip_fragment!(root)
      drop_trailing!(root)
    end

    def self.strip_text(text)
      lines = Support::Utf8.repair(text).to_s.split("\n")
      while lines.any? && trailing_text_line?(lines.last)
        lines.pop
      end
      cleaned = lines.join("\n").strip
      Support::Signature.strip_text(cleaned.presence || text.to_s.strip)
    end

    def self.drop_trailing!(root)
      loop do
        last = last_meaningful(root)
        break unless last

        if trailing_html_node?(last)
          last.remove
        elsif wrapper?(last)
          before = last.inner_html
          drop_trailing!(last)
          last.remove if blank_node?(last)
          break if last.parent && last.inner_html == before
        else
          break
        end
      end
    end

    def self.strip_html(html)
      return if html.blank?

      root = if html.to_s.match?(/<html[\s>]/i)
        parsed = Nokogiri::HTML(html)
        parsed.at("body") || parsed
      else
        Nokogiri::HTML::DocumentFragment.parse(html)
      end
      clean_fragment!(root)
      root.inner_html.to_s.strip.presence
    end

    def self.cut_quoted_thread!(root)
      unwrap = root
      children = meaningful_children(unwrap)
      while children.size == 1 && wrapper?(children.first)
        unwrap = children.first
        children = meaningful_children(unwrap)
      end

      index = children.index { |node| attribution?(node) }
      return unless index&.positive?

      index -= 1 while index.positive? && dump_filler?(children[index - 1])
      return unless index.positive?

      children[index..].each(&:remove)
    end
    private_class_method :cut_quoted_thread!

    def self.trailing_text_line?(line)
      stripped = normalize(line)
      stripped.blank? || line.to_s.strip.start_with?(">") || stripped.match?(ATTRIBUTION)
    end
    private_class_method :trailing_text_line?

    def self.trailing_html_node?(node)
      return false unless node.element?
      return true if %w[blockquote hr].include?(node.name)
      return true if blank_node?(node)

      attribution?(node)
    end
    private_class_method :trailing_html_node?

    def self.attribution?(node)
      normalize(node.text).match?(ATTRIBUTION)
    end
    private_class_method :attribution?

    def self.dump_filler?(node)
      return true if blank_node?(node)
      return false unless node.element? && node.name == "pre"
      return false if node.text.match?(/\{[%{]/)

      true
    end
    private_class_method :dump_filler?

    def self.wrapper?(node)
      node.element? && %w[div span].include?(node.name)
    end
    private_class_method :wrapper?

    def self.blank_node?(node)
      return true if node.text? && node.content.blank?
      return false unless node.element?
      return false if %w[img action-text-attachment figure].include?(node.name)

      node.text.to_s.strip.blank? &&
        node.css("img, action-text-attachment, figure").empty?
    end
    private_class_method :blank_node?

    def self.last_meaningful(root)
      meaningful_children(root).last
    end
    private_class_method :last_meaningful

    def self.meaningful_children(root)
      root.children.select { |node|
        next if node.comment?
        next if node.text? && node.content.blank?

        true
      }
    end
    private_class_method :meaningful_children

    def self.normalize(text)
      Support::Utf8.repair(text.to_s).gsub(/[[:space:]]+/, " ").strip
    end
    private_class_method :normalize
  end
end
