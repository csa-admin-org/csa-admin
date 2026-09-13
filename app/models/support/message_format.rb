# frozen_string_literal: true

require "kramdown"

module Support
  class MessageFormat
    URL = %r{(?<![<(])(https?://[^\s<]+)}

    def self.to_html(text)
      return if text.blank?

      html = Kramdown::Document.new(
        hard_breaks(wrap_urls(fence_code(Support::Utf8.repair(text)))),
        syntax_highlighter: nil).to_html
      ActionController::Base.helpers.sanitize(
        html,
        tags: %w[p br a ul ol li pre code strong em blockquote],
        attributes: %w[href])
    end

    def self.wrap_urls(text)
      in_fence = false
      text.to_s.each_line.map { |line|
        if line.start_with?("~~~")
          in_fence = !in_fence
          line
        elsif in_fence
          line
        else
          line.gsub(URL) { "<#{Regexp.last_match(1)}>" }
        end
      }.join
    end
    private_class_method :wrap_urls

    def self.hard_breaks(text)
      in_fence = false
      text.to_s.each_line.map { |line|
        if line.start_with?("~~~")
          in_fence = !in_fence
          next line
        end
        next line if in_fence || !line.end_with?("\n")

        core = line.chomp
        next line if core.blank? || core.end_with?("  ")

        "#{core}  \n"
      }.join
    end
    private_class_method :hard_breaks

    def self.fence_code(text)
      out = []
      in_code = false
      open_tags = 0

      text.to_s.each_line do |line|
        if in_code
          if still_code?(line, open_tags)
            out << line
            open_tags = next_open_tags(line, open_tags)
          else
            out << "~~~\n\n"
            in_code = false
            out << line
          end
        elsif liquid_start?(line)
          in_code = true
          open_tags = next_open_tags(line, 0)
          out << "\n~~~\n"
          out << line
        else
          out << line
        end
      end
      out << "~~~\n" if in_code
      out.join
    end
    private_class_method :fence_code

    def self.liquid_start?(line)
      line.match?(/\A\s*\{[%{]/)
    end
    private_class_method :liquid_start?

    def self.still_code?(line, open_tags)
      stripped = line.strip.gsub("\u00a0", "").strip
      return true if stripped.blank?
      return true if stripped.match?(/\A\{[%{]/)
      return true if stripped.match?(/\A\d+\z/)
      return true if stripped.include?("%}") || stripped.include?("}}")
      return true if stripped.start_with?("|")
      return true if open_tags.positive?

      false
    end
    private_class_method :still_code?

    def self.next_open_tags(line, open_tags)
      open_tags + line.scan(/\{[%{]/).size - line.scan(/[%}]}/).size
    end
    private_class_method :next_open_tags
  end
end
