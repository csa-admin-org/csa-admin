# frozen_string_literal: true

module Support
  class ReplyBody
    MARKER = /CSA-ADMIN-REPLY-ABOVE/
    EMAIL = /[\w.+\-]+@[\w.\-]+/
    QUOTE_PREFIX = /[>\s"'«»“”‘’„]*/
    QUOTE_SPLIT = %r{
      \n#{QUOTE_PREFIX.source}On[^\n]+wrote:\s*\n? |
      \n#{QUOTE_PREFIX.source}Le[^\n]+a\s+écrit\s*:?\s*\n? |
      \n#{QUOTE_PREFIX.source}Am[^\n]+(?:schrieb\.?:?|hat[^\n]+geschrieben:?)\s*\n? |
      \n#{QUOTE_PREFIX.source}Il\s+giorno[^\n]+ha\s+scritto:?\s*\n? |
      \n#{QUOTE_PREFIX.source}Op[^\n]+schreef[^\n]*:\s*\n? |
      \n#{Support::ReplyQuote::SEPARATOR.source} |
      \n________________________________
    }ix
    FROM_HEADER = /
      (?:^|\n)#{QUOTE_PREFIX.source}(?:De|From|Von)\s*:
      [^\n]*#{EMAIL.source}
    /ix

    def self.extract(text_body:, stripped:, keep_cited: false)
      source = Support::Utf8.repair(text_body.to_s)
      if keep_cited
        body = before_marker(source)
        return Support::ForwardedQuote.wrap(body).presence || body.presence
      end

      body = cut_quoted(Support::Utf8.repair(stripped.to_s)).strip
      body = Support::ReplyQuote.strip_text(body) if body.present?
      return body if body.present?

      Support::ReplyQuote.strip_text(cut_quoted(source))
    end

    def self.without_quote(text)
      cut_quoted(text).strip.presence
    end

    def self.cut_quoted(text)
      before_marker(text.to_s).split(QUOTE_SPLIT, 2).first.to_s
    end
    private_class_method :cut_quoted

    def self.before_marker(text)
      text.to_s.split(MARKER, 2).first.to_s.strip
    end

    def self.original_from(text_body)
      text = Support::Utf8.repair(text_body.to_s)
      header = text[QUOTE_SPLIT] || text[FROM_HEADER]
      header && header[EMAIL]
    end
  end
end
