# frozen_string_literal: true

require "nokogiri"

module Support
  class Signature
    def self.name
      ENV["ULTRA_ADMIN_NAME"].to_s.strip.presence
    end

    def self.strip_text(text)
      source = text.to_s
      return source if name.blank? || !source.match?(pattern)

      source.sub(pattern, "").rstrip
    end

    def self.strip_fragment!(root)
      return if name.blank?

      loop do
        unwrap = unwrap_root(root)
        children = meaningful_children(unwrap)
        break if children.empty?

        if combined_signature?(children.last)
          children.last.remove
          next
        end
        if children.size >= 2 && marker?(children[-2]) && name_node?(children[-1])
          children[-1].remove
          children[-2].remove
          next
        end

        last = children.last
        if wrapper?(last)
          before = last.inner_html
          strip_fragment!(last)
          last.remove if blank_node?(last)
          break if last.parent && last.inner_html == before
          next
        end

        break
      end
    end

    def self.append_text(text)
      source = text.to_s
      return source if name.blank? || signed?(source)

      "#{source.rstrip}\n\n++\n#{name}"
    end

    def self.append_html(html)
      source = html.to_s
      return source if name.blank? || signed?(source)

      "#{source.rstrip}\n#{html_signature}"
    end

    def self.signed?(source)
      return false if name.blank?

      plain(source).match?(pattern)
    end

    def self.pattern
      /
        (?:\A|\n)
        (?:\+\+|--)+
        [[:space:]]*
        (?:\n[[:space:]]*)?
        #{Regexp.escape(name.to_s)}
        [[:space:]]*
        \z
      /ix
    end
    private_class_method :pattern

    def self.plain(source)
      html = source.to_s
      return html unless html.match?(/<[a-z][\s\S]*>/i)

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.css("br").each { |node| node.replace("\n") }
      fragment.css("p, div").each { |node| node.add_next_sibling("\n") }
      fragment.text
    end
    private_class_method :plain

    def self.html_signature
      %(<p>++<br>#{ERB::Util.html_escape(name)}</p>)
    end
    private_class_method :html_signature

    def self.unwrap_root(root)
      unwrap = root
      children = meaningful_children(unwrap)
      while children.size == 1 && wrapper?(children.first)
        unwrap = children.first
        children = meaningful_children(unwrap)
      end
      unwrap
    end
    private_class_method :unwrap_root

    def self.combined_signature?(node)
      normalize(node.text).match?(/\A(?:\+\+|--)+\s+#{Regexp.escape(name)}\z/i)
    end
    private_class_method :combined_signature?

    def self.marker?(node)
      normalize(node.text).match?(/\A(?:\+\+|--)+\z/)
    end
    private_class_method :marker?

    def self.name_node?(node)
      normalize(node.text).casecmp?(name)
    end
    private_class_method :name_node?

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

    def self.meaningful_children(root)
      root.children.select { |node|
        next if node.comment?
        next if node.element? && node.name == "br"
        next if node.text? && node.content.blank?

        true
      }
    end
    private_class_method :meaningful_children

    def self.normalize(text)
      text.to_s.gsub(/[[:space:]]+/, " ").strip
    end
    private_class_method :normalize
  end
end
