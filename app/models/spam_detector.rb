class SpamDetector
  MAX_SIZE = 5000
  ZIP_REGEXP = /\A\d{6}\z/
  CYRILLIC_CHECK = /\p{Cyrillic}+/ui
  TEXTS_COLUMNS = %w[note food_note come_from].freeze

  def self.spam?(member)
    new(member).spam?
  end

  def self.notify!(member)
    Sentry.capture_message('Spam detected', extra: member.attributes)
  end

  def initialize(member)
    @member = member
  end

  def spam?
    @member.note.to_s.size > MAX_SIZE ||
      @member.food_note.to_s.size > MAX_SIZE ||
      @member.zip&.match?(ZIP_REGEXP) ||
      @member.address&.match?(CYRILLIC_CHECK) ||
      @member.city&.match?(CYRILLIC_CHECK) ||
      @member.come_from&.match?(CYRILLIC_CHECK) ||
      non_native_language? ||
      long_duplicated_texts?
  end

  def non_native_language?
    languages = I18n.available_locales.map(&:to_s)
    languages << 'un' # Unknown CLD language
    TEXTS_COLUMNS.any? { |attr|
      text = @member.send(attr).dup
      if text && text.size > 100
        cld = CLD.detect_language(text)
        cld[:reliable] && languages.exclude?(cld[:code])
      end
    }
  end

  def long_duplicated_texts?
    texts = TEXTS_COLUMNS.map { |attr|
      text = @member.send(attr).dup
      if text.present? && text.size > 40
        text.gsub!(/\s/, '')
      end
    }.compact
    texts.any? { |t| texts.count(t) > 1 }
  end
end
