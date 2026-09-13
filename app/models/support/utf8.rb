# frozen_string_literal: true

module Support
  module Utf8
    MARKERS = /Ã.|Â[[:space:]]|Â[€,:;!?.]|Ã |Â©/

    def self.repair(text)
      source = text.to_s
      return source if source.blank?
      return source unless source.match?(MARKERS)

      candidate = source
      2.times do
        repaired = recode(candidate)
        break if repaired == candidate

        candidate = repaired
      end
      candidate
    end

    def self.repair_fragment!(root)
      root.xpath(".//text()").each do |node|
        next if node.content.blank?

        repaired = repair(node.content)
        node.content = repaired unless repaired == node.content
      end
    end

    def self.recode(text)
      out = +""
      chars = text.chars
      i = 0
      while i < chars.size
        ch = chars[i]
        nxt = chars[i + 1]
        if nxt && (pair = recode_pair(ch, nxt))
          out << pair
          i += 2
        else
          out << ch
          i += 1
        end
      end
      out
    end
    private_class_method :recode

    def self.recode_pair(first, second)
      if first == "Ã" && second == " "
        return "à "
      end
      if first == "Â" && second.match?(/[[:space:]]/)
        return second == "\u00a0" ? " " : second
      end
      return unless first.ord.between?(0xC2, 0xC3) && second.ord.between?(0x80, 0xBF)

      recoded = (first + second).encode("ISO-8859-1").force_encoding("UTF-8")
      recoded if recoded.valid_encoding?
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      nil
    end
    private_class_method :recode_pair
  end
end
