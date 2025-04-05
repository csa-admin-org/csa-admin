# frozen_string_literal: true

module NormalizedString
  extend ActiveSupport::Concern

  class_methods do
    def normalized_string_attributes(*attrs)
      normalizes(*attrs, with: ->(value) {
        value
          &.squish                                              # Remove leading and trailing whitespace
          &.gsub(/[\u2013\u2014]/, "-")                         # Replace fancy dashes with a hyphen
          &.gsub(/[\u2018\u2019\u201A\u201B\u2039\u203A]/, "'") # Replace fancy single quotes with an ASCII apostrophe
          &.gsub(/[\u201C\u201D\u201E\u201F\u2033\u2036]/, '"') # Replace fancy double quotes with ASCII quotes
          &.gsub(/[\u00A0\u2007\u202F]/, " ")                   # Replace whitespace characters with a space
          &.gsub(/[\u00AD\u200B]/, "")                          # Remove soft hyphens and zero-width spaces
          &.unicode_normalize(:nfkc)                            # Normalize Unicode characters
          &.strip.presence
      })
    end
  end
end
