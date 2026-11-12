# frozen_string_literal: true

require "json"

module AnonymizedDump
  # Removes leftovers that sit inside free text and JSON after column rules
  # have run: production Active Storage URLs, signed ids, and IBANs copied
  # into invoice footers or notes.
  module Scrub
    ACTIVE_STORAGE_URL = %r{/rails/active_storage/[^"'\s>]+}
    SGID = /\bsgid="[^"]+"/

    module_function

    def text(value, iban:)
      updated = value.to_s
        .gsub(ACTIVE_STORAGE_URL, "#")
        .gsub(SGID, 'sgid=""')
      IBAN.replace(updated, with: iban)
    end

    def json_value(value, iban:)
      parsed = value.is_a?(String) ? JSON.parse(value) : value
      generated = JSON.generate(strip_signed_ids(parsed))
      text(generated, iban: iban)
    rescue JSON::ParserError
      text(value.to_s, iban: iban)
    end

    def strip_signed_ids(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, inner), cleaned|
          next if key.to_s == "signed_id"

          cleaned[key] = strip_signed_ids(inner)
        end
      when Array
        value.map { |inner| strip_signed_ids(inner) }
      else
        value
      end
    end

    def candidate?(value)
      text = value.to_s
      text.include?("/rails/active_storage/") ||
        text.include?("signed_id") ||
        text.match?(/\bsgid="/) ||
        IBAN.each_valid(text).any?
    end
  end
end
