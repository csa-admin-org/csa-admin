# frozen_string_literal: true

module Organization::DeliveryPDF
  extend ActiveSupport::Concern

  MEMBER_INFOS = %w[none phones food_note]
  MEMBER_NAME_SEGMENT_SEPARATOR = /(\s*,\s*|\s+(?:und|en|et|and|&)\s+)/i

  included do
    translated_attributes :delivery_pdf_footer

    enum :delivery_pdf_member_name_format, {
      full_name: "none",
      abbreviate_first: "abbreviate_first",
      abbreviate_last: "abbreviate_last",
      initials: "initials"
    }

    validates :delivery_pdf_member_info,
      presence: true,
      inclusion: { in: MEMBER_INFOS }
  end

  def format_member_name_for_pdf(name)
    return name if full_name?

    parts = name.split(MEMBER_NAME_SEGMENT_SEPARATOR)
    non_sep_indices = parts.each_index.reject { |i| parts[i].match?(MEMBER_NAME_SEGMENT_SEPARATOR) }

    # A single one-word name has nothing meaningful to abbreviate
    return name if non_sep_indices.length == 1 && parts[non_sep_indices.first].strip.split(" ").length == 1

    last_seg_idx = non_sep_indices.length - 1
    non_sep_indices.each_with_index do |part_idx, seg_idx|
      part  = parts[part_idx]
      words = part.strip.split(" ")
      leading = part.start_with?(" ") ? " " : ""

      parts[part_idx] = if abbreviate_last?
        if words.length > 1
          "#{leading}#{[ *words[0..-2], "#{words.last[0]}." ].join(" ")}"
        elsif seg_idx == last_seg_idx
          "#{leading}#{words.first[0]}."
        else
          part
        end
      elsif abbreviate_first?
        if words.length > 1
          "#{leading}#{[ "#{words.first[0]}.", *words[1..] ].join(" ")}"
        elsif seg_idx == 0
          "#{leading}#{words.first[0]}."
        else
          part
        end
      else # initials
        "#{leading}#{words.map { |w| "#{w[0]}." }.join(" ")}"
      end
    end

    parts.join
  end
end
