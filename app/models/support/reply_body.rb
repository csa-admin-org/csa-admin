# frozen_string_literal: true

module Support
  class ReplyBody
    MARKER = /CSA-ADMIN-REPLY-ABOVE/
    QUOTE_SPLIT = %r{
      \nOn[^\n]+wrote:\s*\n |
      \nLe[^\n]+a\s+écrit\s*:?\s*\n |
      \nAm[^\n]+schrieb\.?:?\s*\n |
      \nIl\s+giorno[^\n]+ha\s+scritto:?\s*\n |
      \nOp[^\n]+schreef[^\n]*:\s*\n |
      \n-----Original\s+Message----- |
      \n________________________________
    }ix

    EMAIL = /[\w.+\-]+@[\w.\-]+/

    def self.extract(text_body:, stripped:, keep_cited: false)
      source = Support::Utf8.repair(text_body.to_s)
      if keep_cited
        body = before_marker(source)
        return Support::ForwardedQuote.wrap(body).presence || body.presence
      end

      body = Support::Utf8.repair(stripped.to_s).strip
      body = before_marker(body) if body.present?
      body = Support::ReplyQuote.strip_text(body) if body.present?
      return body if body.present?

      Support::ReplyQuote.strip_text(
        before_marker(source.split(QUOTE_SPLIT, 2).first.to_s))
    end

    def self.before_marker(text)
      text.to_s.split(MARKER, 2).first.to_s.strip
    end

    def self.original_from(text_body)
      header = Support::Utf8.repair(text_body.to_s)[QUOTE_SPLIT]
      header && header[EMAIL]
    end
  end
end
