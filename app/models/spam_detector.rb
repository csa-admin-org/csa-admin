class SpamDetector
  SpamDetectedError = Class.new(StandardError)

  MAX_SIZE = 5000
  ZIP_REGEXP = /\A\d{6}\z/
  CYRILLIC_CHECK = /\p{Cyrillic}+/ui

  def self.spam?(member)
    new(member).spam?
  end

  def self.notify!(member)
    ExceptionNotifier.notify(SpamDetectedError.new, member.attributes)
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
      non_native_language?
  end

  def non_native_language?
    languages = Current.acp.languages
    languages << 'un' # Unknown CLD language
    %w[note food_note come_from].any? { |attr|
      text = @member.send(attr)
      if text && text.size > 40
        cld = CLD.detect_language(text)
        cld[:reliable] && languages.exclude?(cld[:code])
      end
    }
  end
end
