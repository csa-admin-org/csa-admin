# frozen_string_literal: true

require "nokogiri"

module Support
  class MessageHtml
    BROKEN_IMAGE = /!\[.*?\](?:\([^)]*\))?/
    LIQUID_TOKEN = /\{[%{]/
    GLUE_TEXT = /\A[[:space:]\d]*\z/

    def self.rewrite(html)
      source = html.to_s
      return html if source.blank?

      fragment = Nokogiri::HTML::DocumentFragment.parse(source)
      Support::Utf8.repair_fragment!(fragment)
      drop_broken_markdown!(fragment)
      merge_liquid!(fragment)
      format_liquid_pres!(fragment)
      fragment.to_html.html_safe
    end

    def self.drop_broken_markdown!(root)
      root.xpath(".//text()").each do |node|
        next if skip_code?(node)
        next unless node.content.include?("![")

        node.content = node.content.gsub(BROKEN_IMAGE, "")
        parent = node.parent
        next unless parent&.name == "p"
        next if parent.text.match?(/\S/)
        next if parent.css("a, img, action-text-attachment, figure").any?

        parent.remove
      end
    end
    private_class_method :drop_broken_markdown!

    def self.merge_liquid!(root)
      nodes = meaningful_children(root)
      while nodes.size == 1 && nodes.first.element? && nodes.first.name == "div"
        root = nodes.first
        nodes = meaningful_children(root)
      end
      i = 0
      while i < nodes.size
        unless liquid_pre?(nodes[i])
          i += 1
          next
        end

        j = i + 1
        loop do
          break if j >= nodes.size

          if liquid_glue?(nodes[j])
            j += 1
            next
          end
          if j > i + 1 && liquid_pre?(nodes[j])
            j += 1
            next
          end
          break
        end
        absorbed = nodes[i...j]
        if absorbed.size > 1
          replace_with_pre!(absorbed)
          nodes = meaningful_children(root)
          i = 0
          next
        end
        i = j
      end
    end
    private_class_method :merge_liquid!

    def self.replace_with_pre!(nodes)
      code = format_liquid(nodes.map { |node| liquid_text(node) }.join("\n"))
      pre = Nokogiri::XML::Node.new("pre", nodes.first.document)
      code_node = Nokogiri::XML::Node.new("code", nodes.first.document)
      code_node.content = code
      pre.add_child(code_node)
      nodes.first.add_previous_sibling(pre)
      nodes.each(&:remove)
    end
    private_class_method :replace_with_pre!

    def self.format_liquid_pres!(root)
      root.css("pre").each do |pre|
        next unless pre.text.match?(LIQUID_TOKEN)

        formatted = format_liquid(pre.text)
        code = pre.at("code") || pre
        code.content = formatted unless code.text == formatted
      end
    end
    private_class_method :format_liquid_pres!

    FILTERS = %w[
      divided_by times plus minus round modulo at_least at_most
      date where default append prepend replace split join first last
      map sort uniq abs ceil floor size compact strip escape
    ].freeze
    private_constant :FILTERS

    def self.format_liquid(code)
      source = code.to_s.gsub("\u00a0", " ")
      return source.strip unless needs_format?(source)

      flatten_filters(source).map { |line|
        line.start_with?("{%") ? line : "  #{line}"
      }.join("\n")
    end
    private_class_method :format_liquid

    def self.needs_format?(code)
      lines = code.split(/\n+/).map { |line| line.strip }.reject(&:blank?)
      return false if lines.empty?
      return true if lines.any? { |line| filter_continuation?(line) }
      return true if lines.any? { |line|
        line.start_with?("{{") && !line.include?("|") &&
          FILTERS.any? { |name| line.match?(/\b#{Regexp.escape(name)}\b/) }
      }

      liquid_only?(lines) && code.match?(/\n\s*\n/)
    end
    private_class_method :needs_format?

    def self.liquid_only?(lines)
      lines.all? { |line|
        line.start_with?("{%", "{{") || line.match?(/\A\d+\z/)
      }
    end
    private_class_method :liquid_only?

    def self.flatten_filters(code)
      lines = code.split(/\n+/).map { |line| line.strip }.reject(&:blank?)
      out = []
      lines.each do |line|
        if filter_continuation?(line) && out.last&.include?("{{")
          fragment = line.delete_prefix("|").strip
          out[-1] = out[-1].sub(/\s*\}\}\s*\z/, "").rstrip + " | #{fragment}"
          out[-1] += " }}" unless out[-1].include?("}}")
        else
          out << restore_pipes(line)
        end
      end
      out
    end
    private_class_method :flatten_filters

    def self.filter_continuation?(line)
      name = line.delete_prefix("|").strip.sub(/\s*\}\}\s*\z/, "")
      name.match?(/\A\w+:/) || FILTERS.include?(name)
    end
    private_class_method :filter_continuation?

    def self.restore_pipes(line)
      return line if line.include?("|") || !line.start_with?("{{")

      FILTERS.each do |name|
        line = line.gsub(/(?<![|])\s+(#{Regexp.escape(name)}:)/, " | \\1")
        line = line.gsub(/(?<![|])\s+(#{Regexp.escape(name)})(?=\s*\}\}|\z)/, " | \\1")
      end
      line = line.gsub(/\s+/, " ")
      line.sub(/\A\{\{\s*/, "{{ ").sub(/\s*\}\}\z/, " }}")
    end
    private_class_method :restore_pipes

    def self.liquid_pre?(node)
      node.element? && node.name == "pre" && node.text.match?(LIQUID_TOKEN)
    end
    private_class_method :liquid_pre?

    def self.liquid_glue?(node)
      return true if node.text? && node.content.match?(LIQUID_TOKEN)
      return true if node.element? && node.name == "p" && node.text.match?(GLUE_TEXT)
      return true if node.element? && node.name == "table" && node.text.match?(LIQUID_TOKEN)

      false
    end
    private_class_method :liquid_glue?

    def self.liquid_text(node)
      if node.element? && node.name == "table"
        node.css("tr").map { |row|
          row.css("td, th").map { |cell| cell.text.gsub(/[[:space:]]+/, " ").strip }.join("\n")
        }.join("\n")
      else
        node.text.gsub("\u00a0", " ")
      end
    end
    private_class_method :liquid_text

    def self.meaningful_children(root)
      root.children.select { |node|
        next if node.comment?
        next if node.text? && node.content.blank?

        true
      }
    end
    private_class_method :meaningful_children

    def self.skip_code?(node)
      node.ancestors.any? { |ancestor| %w[pre code].include?(ancestor.name) }
    end
    private_class_method :skip_code?
  end
end
