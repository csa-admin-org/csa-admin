# frozen_string_literal: true

# Heading-based search over raw handbook markdown files.
#
# Parses h1/h2 headings directly from markdown using regex — no ERB
# rendering needed because heading lines are plain text. Uses the same
# normalization as SearchEntry (transliterate + downcase) so that
# accent-insensitive matching works consistently.
#
# Results are cached per locale for the lifetime of the process since
# handbook content is static (only changes on deploy/restart).
module Handbook::Search
  extend ActiveSupport::Concern

  # Regex to extract headings from raw markdown. H1/H2 lines in handbook
  # files contain only plain text — no ERB expressions — so regex is safe.
  H1_REGEX = /^#\s+(.+?)$/
  H2_REGEX = /^##\s+(.+?)\s*\{#([\w-]+)\}$/

  class_methods do
    # Search handbook headings for a query string, returning matches sorted
    # by relevance (title matches first, then subtitle matches).
    #
    # Returns an array of hashes:
    #   { name:, title:, subtitle:, anchor:, page_title: }
    #
    #   - Title match:    subtitle/anchor/page_title are nil
    #   - Subtitle match: subtitle is the heading text, anchor is the {#id},
    #                     page_title is the parent page's h1 title
    #
    def search(query, locale: I18n.locale)
      query = query.to_s.strip
      return [] if query.length < 2

      normalized_query = SearchEntry.normalize_text(query)
      return [] if normalized_query.blank?

      terms = normalized_query.split(/\s+/).reject(&:blank?)
      return [] if terms.empty?

      results = []

      headings_for(locale).each do |page|
        next if Organization.restricted_features.include?(page[:name].to_sym)
        next if Current.org.inactive_feature?(page[:name])

        if terms.all? { |term| page[:normalized_title].include?(term) }
          results << {
            name: page[:name],
            title: page[:title],
            subtitle: nil,
            anchor: nil,
            page_title: nil
          }
        end

        page[:subtitles].each do |subtitle_text, anchor, normalized_subtitle|
          if terms.all? { |term| normalized_subtitle.include?(term) }
            results << {
              name: page[:name],
              title: page[:title],
              subtitle: subtitle_text,
              anchor: anchor,
              page_title: page[:title]
            }
          end
        end
      end

      # Title matches rank higher than subtitle matches
      results.sort_by { |r| r[:subtitle] ? 1 : 0 }
    end

    # Parsed headings for a locale, cached for the lifetime of the process.
    # Handbook content is static — only changes on deploy/restart.
    def headings_for(locale)
      @headings ||= {}
      @headings[locale.to_sym] ||= parse_headings(locale)
    end

    def clear_headings_cache!
      @headings = {}
    end

    private

    def parse_headings(locale)
      path = Rails.root.join(Handbook::DIR_PATH, "*.#{locale}.md.erb")
      Dir.glob(path).filter_map { |filepath|
        name = File.basename(filepath, ".#{locale}.md.erb")
        content = File.read(filepath)

        title = content[H1_REGEX, 1]
        next unless title

        subtitles = content.scan(H2_REGEX).map { |text, anchor|
          [ text, anchor, SearchEntry.normalize_text(text) ]
        }

        {
          name: name,
          title: title,
          normalized_title: SearchEntry.normalize_text(title),
          subtitles: subtitles
        }
      }
    end
  end
end
