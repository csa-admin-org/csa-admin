# frozen_string_literal: true

module Support
  class ForwardedQuote
    HEADER_LABEL = /(?:De|From|Von|À|To|An|Cc|Objet|Subject|Betreff|Date|Envoyé|Sent|Sujet)/i
    MARKER = /
      Message[ ]d['’]origine |
      Forwarded[ ]message |
      Original[ ]Message |
      Message[ ]transféré |
      Début[ ]du[ ]message |
      Anfang[ ]der[ ]weitergeleiteten[ ]Nachricht
    /ix

    def self.wrap(text)
      own, quoted = split(text)
      return text if quoted.blank?

      "#{own.strip}\n\n#{as_markdown(quoted)}"
    end

    def self.split(text)
      normalized = normalize(text)
      idx = sep_index(normalized) || outlook_index(normalized) || cite_index(normalized)
      return [ text, "" ] unless idx&.positive?

      [ normalized[0...idx], normalized[idx..] ]
    end

    def self.original?(text)
      sample = normalize(text)[0, 800]
      return true if sample.match?(MARKER)
      return true if sample.match?(/\A[-_]{5,}/) && sample.match?(MARKER)

      sample.match?(/(?:De|From|Von)\s*:/) &&
        sample.match?(/(?:Envoyé|Sent|Date|Objet|Subject|Betreff|À|To)\s*:/)
    end

    def self.normalize(text)
      text.to_s.gsub("\u00a0", " ").gsub("\r\n", "\n").gsub("\r", "\n")
    end
    private_class_method :normalize

    def self.sep_index(text)
      match = text.match(
        %r{
          (?:\A|\n)
          (?:
            [-_]{5,}\s*#{MARKER.source}[-_\s]* |
            #{MARKER.source}[^\n]*
          )
        }ix)
      match&.begin(0)
    end
    private_class_method :sep_index

    def self.outlook_index(text)
      offset = 0
      text.each_line do |line|
        if line.strip.match?(/\A(?:De|From|Von)\s*:/i)
          window = text[offset..].to_s.lines.first(8).join
          return offset if window.match?(/Envoyé|Sent|Date|Objet|Subject|Betreff|À\s*:|To\s*:/i)
        end
        offset += line.length
      end
      nil
    end
    private_class_method :outlook_index

    def self.cite_index(text)
      match = text.match(Support::ReplyBody::QUOTE_SPLIT)
      match&.begin(0)
    end
    private_class_method :cite_index

    def self.as_markdown(quoted)
      unmash(quoted).strip.each_line.map { |line|
        core = line.chomp
        next ">" if core.blank?
        next line if core.start_with?(">")

        "> #{core}"
      }.join("\n")
    end
    private_class_method :as_markdown

    def self.unmash(quoted)
      text = quoted.to_s.sub(/\A\s+/, "")
      text = text.sub(
        /\A((?:[-_]{5,}\s*)?#{MARKER.source}[-_\s]*)/i,
        "\\1\n")
      text = text.gsub(/mailto:/i, "mailto\u0000")
      text = text.gsub(/(?<=\S)(?=#{HEADER_LABEL.source}\s*:)/i, "\n")
      text.gsub("mailto\u0000", "mailto:")
    end
    private_class_method :unmash
  end
end
