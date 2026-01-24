# frozen_string_literal: true

class SpamDetector < SimpleDelegator
  TEXT_ATTRS = %i[note food_note come_from]
  ADDRESS_ATTRS = %i[street city zip]

  def self.spam?(member)
    new(member).spam?
  end

  def self.notify!(member)
    return if new(member).non_allowed_country?

    text = ADDRESS_ATTRS.map { member.send(it) }.join
    return if new(member).gibberish?(text)

    Rails.error.unexpected("Spam detected", context: member.attributes)
  end

  def spam?
    non_allowed_country?
      || TEXT_ATTRS.any? { too_long_text?(send(it)) }
      || (%i[come_from] + ADDRESS_ATTRS).any? { cyrillic?(send(it)) }
      || (%i[name] + ADDRESS_ATTRS + TEXT_ATTRS).any? { gibberish?(send(it)) }
      || long_duplicated_texts?(TEXT_ATTRS)
  end

  def non_allowed_country?
    allowed_country_codes = ENV["ALLOWED_COUNTRY_CODES"].to_s.split(",")
    return false unless allowed_country_codes.any?

    allowed_country_codes.exclude?(country_code)
  end

  def too_long_text?(text, max_length: 5000)
    return if text.blank?

    text.length >= max_length
  end

  def cyrillic?(text)
    return if text.blank?

    text.match?(/\p{Cyrillic}+/ui)
  end

  def gibberish?(text, min_length: 20, max_ratio: 0.69)
    return if text.blank? || text.length < min_length || text =~ /[^\p{L}]/

    letters = text.scan(/\p{L}/)
    consonants = letters.count { |c| !/[aeiou]/i.match?(c) }
    total_letters = letters.length
    return if total_letters < 5

    ratio = consonants.to_f / total_letters
    ratio > max_ratio
  end

  def long_duplicated_texts?(attrs)
    texts = attrs.map { |attr|
      text = send(attr)
      if text.present? && text.size > 40
        text.gsub(/\s/, "")
      end
    }.compact
    texts.any? { |t| texts.count(t) > 1 }
  end
end
