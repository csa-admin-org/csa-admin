# frozen_string_literal: true

module AnonymizedDump
  # ISO 13616 IBAN checksums. Faker::Bank.iban is not deterministic and is
  # not checked against IBANTools, which is what SEPAMandate uses.
  module IBAN
    BBAN_LENGTH = {
      "CH" => 17,
      "DE" => 18,
      "FR" => 23,
      "NL" => 14
    }.freeze

    COMPACT = /\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/
    GROUPED = /\b[A-Z]{2}\d{2}(?: [A-Z0-9]{1,4}){3,8}\b/

    module_function

    def generate(country:, seed:)
      code = country.to_s.upcase
      code = "CH" unless BBAN_LENGTH.key?(code)
      compose(code, bban_for(code, seed))
    end

    def compose(country, bban)
      check = 98 - mod97("#{bban}#{country}00")
      format("%s%02d%s", country, check, bban)
    end

    def valid?(value)
      require "iban-tools"
      IBANTools::IBAN.valid?(value.to_s.delete(" "))
    end

    def each_valid(text)
      return enum_for(:each_valid, text) unless block_given?

      text.to_s.scan(GROUPED) do |token|
        compact = token.delete(" ")
        yield token, compact if valid?(compact)
      end
      text.to_s.scan(COMPACT) do |token|
        yield token, token if valid?(token)
      end
    end

    def replace(text, with:)
      updated = text.to_s.gsub(GROUPED) { |token|
        valid?(token.delete(" ")) ? with : token
      }
      updated.gsub(COMPACT) { |token| valid?(token) ? with : token }
    end

    def mod97(string)
      digits = string.upcase.chars.map { |char|
        char.match?(/\d/) ? char : (char.ord - 55).to_s
      }.join
      digits.to_i % 97
    end

    def bban_for(country, seed)
      rng = Random.new(seed)
      if country == "NL"
        letters = ("A".."Z").to_a
        bank = 4.times.map { letters.fetch(rng.rand(26)) }.join
        account = 10.times.map { rng.rand(10) }.join
        "#{bank}#{account}"
      else
        length = BBAN_LENGTH.fetch(country)
        digits = length.times.map { rng.rand(10) }.join
        digits = "1" if digits.match?(/\A0+\z/)
        digits.rjust(length, "0")
      end
    end
  end
end
