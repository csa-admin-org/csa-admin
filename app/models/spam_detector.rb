# frozen_string_literal: true

require "cld"

class SpamDetector < SimpleDelegator
  MAX_LENGTH = 5000
  CYRILLIC_CHECK = /\p{Cyrillic}+/ui
  TEXTS_ATTRS = %i[note food_note come_from].freeze
  GIBBERISH_ATTRS = %i[name address city zip come_from note].freeze
  GIBBERISH_MIN_LENGTH = 20
  GIBBERISH_RATIO = 0.74

  def self.spam?(member)
    new(member).spam?
  end

  def self.notify!(member)
    return if new(member).non_allowed_country?
    return if new(member).gibberish_text?(:zip)

    Error.notify("Spam detected", **member.attributes)
  end

  def spam?
    note.to_s.length > MAX_LENGTH ||
      food_note.to_s.length > MAX_LENGTH ||
      address&.match?(CYRILLIC_CHECK) ||
      city&.match?(CYRILLIC_CHECK) ||
      come_from&.match?(CYRILLIC_CHECK) ||
      non_native_language? ||
      long_duplicated_texts? ||
      non_allowed_country? ||
      gibberish?
  end

  def non_allowed_country?
    allowed_country_codes = ENV["ALLOWED_COUNTRY_CODES"].to_s.split(",")
    return false unless allowed_country_codes.any?

    allowed_country_codes.exclude?(country_code)
  end

  def non_native_language?
    languages = I18n.available_locales.map(&:to_s)
    languages << "un" # Unknown CLD language
    TEXTS_ATTRS.any? { |attr|
      text = send(attr)
      if text && text.size > 100
        cld = CLD.detect_language(text)
        cld[:reliable] && languages.exclude?(cld[:code])
      end
    }
  end

  def long_duplicated_texts?
    texts = TEXTS_ATTRS.map { |attr|
      text = send(attr)
      if text.present? && text.size > 40
        text.gsub(/\s/, "")
      end
    }.compact
    texts.any? { |t| texts.count(t) > 1 }
  end

  def gibberish?
    GIBBERISH_ATTRS.any? { |attr| gibberish_text?(attr) }
  end

  def gibberish_text?(attr, min_length: GIBBERISH_MIN_LENGTH, max_ratio: GIBBERISH_RATIO)
    text = send(attr)
    return if text.blank? || text.length < min_length || text =~ /[^\p{L}]/

    letters = text.scan(/\p{L}/)
    consonants = letters.count { |c| !/[aeiou]/i.match?(c) }
    total_letters = letters.length
    return if total_letters < 5

    ratio = consonants.to_f / total_letters
    ratio > max_ratio
  end
end
