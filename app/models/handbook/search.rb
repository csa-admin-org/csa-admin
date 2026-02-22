# frozen_string_literal: true

# Heading-based and full-content search over raw handbook markdown files.
#
# Two search modes:
#   1. `search` — matches h1/h2 headings only (used by global search modal)
#   2. `content_search` — matches full page body text (used by handbook sidebar)
#
# Parses h1/h2 headings directly from markdown using regex — no ERB
# rendering needed because heading lines are plain text. Uses the same
# normalization as SearchEntry (transliterate + downcase) so that
# accent-insensitive matching works consistently.
#
# For content search, ERB tags are stripped (not evaluated) and markdown
# formatting is cleaned to produce plain searchable text.
#
# Results are cached per locale for the lifetime of the process since
# handbook content is static (only changes on deploy/restart).
module Handbook::Search
  extend ActiveSupport::Concern

  # Regex to extract headings from raw markdown. H1/H2 lines in handbook
  # files contain only plain text — no ERB expressions — so regex is safe.
  H1_REGEX = /^#\s+(.+?)$/
  H2_REGEX = /^##\s+(.+?)\s*\{#([\w-]+)\}$/

  # Maximum snippet length (characters) for content search results.
  SNIPPET_LENGTH = 120

  # Maximum number of content search results returned.
  MAX_CONTENT_RESULTS = 10

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

      terms = SearchEntry.search_terms(query)
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
          combined = "#{page[:normalized_title]} #{normalized_subtitle}"
          if terms.all? { |term| combined.include?(term) }
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

    # Full-content search across all handbook pages. Searches page titles,
    # section headings, and body text. Returns results with context snippets
    # for display in the handbook sidebar.
    #
    # Returns an array of hashes:
    #   { name:, title:, heading:, anchor:, snippet: }
    #
    #   - heading/anchor are nil for title-level or intro-section matches
    #   - snippet is ~120 chars of raw text centered around the first match
    #     (highlighted in the view via the highlight_search helper)
    #
    def content_search(query, locale: I18n.locale)
      query = query.to_s.strip
      return [] if query.length < 3

      terms = SearchEntry.search_terms(query)
      return [] if terms.empty?

      results = []

      pages_for(locale).each do |page|
        next if Organization.restricted_features.include?(page[:name].to_sym)

        # Check title match
        if terms.all? { |term| page[:normalized_title].include?(term) }
          results << {
            name: page[:name],
            title: page[:title],
            heading: nil,
            anchor: nil,
            snippet: build_snippet(page[:sections].first, terms),
            rank: 0
          }
          next # One result per page — title match is best
        end

        # Check each section (heading match or body match)
        best_section_result = nil

        page[:sections].each do |section|
          heading_match = section[:normalized_heading] &&
            terms.all? { |term| section[:normalized_heading].include?(term) }

          body_match = terms.all? { |term| section[:normalized_text].include?(term) }

          if heading_match
            candidate = {
              name: page[:name],
              title: page[:title],
              heading: section[:heading],
              anchor: section[:anchor],
              snippet: build_snippet(section, terms),
              rank: 1
            }
            # Prefer heading matches over body-only matches
            if best_section_result.nil? || best_section_result[:rank] > 1
              best_section_result = candidate
            end
          elsif body_match && best_section_result.nil?
            best_section_result = {
              name: page[:name],
              title: page[:title],
              heading: section[:heading],
              anchor: section[:anchor],
              snippet: build_snippet(section, terms),
              rank: 2
            }
          end
        end

        results << best_section_result if best_section_result
      end

      results
        .sort_by { |r| r[:rank] }
        .first(MAX_CONTENT_RESULTS)
        .map { |r| r.except(:rank) }
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

    # Parsed full pages for a locale, cached for the lifetime of the process.
    # Used by content_search for full-text matching with snippets.
    def pages_for(locale)
      @pages ||= {}
      @pages[locale.to_sym] ||= parse_pages(locale)
    end

    def clear_pages_cache!
      @pages = {}
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

    # Parse each markdown file into sections split by ## headings.
    # ERB tags are stripped, markdown formatting is cleaned to produce
    # plain searchable text.
    def parse_pages(locale)
      path = Rails.root.join(Handbook::DIR_PATH, "*.#{locale}.md.erb")
      Dir.glob(path).filter_map { |filepath|
        name = File.basename(filepath, ".#{locale}.md.erb")
        content = File.read(filepath)

        title = content[H1_REGEX, 1]
        next unless title

        cleaned = strip_erb_tags(content)
        sections = split_into_sections(cleaned)

        {
          name: name,
          title: title,
          normalized_title: SearchEntry.normalize_text(title),
          sections: sections
        }
      }
    end

    # Remove ERB tags: <% ... %> and <%= ... %> (including multiline).
    # This avoids showing Ruby code in search results (e.g. dynamic
    # activity names via <%= activities_human_name %>).
    def strip_erb_tags(text)
      text.gsub(/<%=?.*?%>/m, "")
    end

    # Split markdown content into sections by ## headings.
    # The first section (before any ##) captures the intro text after the H1.
    # Each section stores its heading text, anchor, raw cleaned text, and
    # normalized text for matching.
    def split_into_sections(content)
      # Remove the H1 line itself from content
      content = content.sub(H1_REGEX, "").lstrip

      parts = content.split(/^(?=##\s)/)
      parts.map { |part|
        heading_match = part.match(H2_REGEX)
        if heading_match
          heading = heading_match[1]
          anchor = heading_match[2]
          # Remove the heading line from the body text
          body = part.sub(H2_REGEX, "").strip
        else
          heading = nil
          anchor = nil
          body = part.strip
        end

        raw_text = clean_markdown(body)

        {
          heading: heading,
          anchor: anchor,
          normalized_heading: heading ? SearchEntry.normalize_text(heading) : nil,
          raw_text: raw_text,
          normalized_text: SearchEntry.normalize_text(raw_text)
        }
      }
    end

    # Strip markdown formatting to produce plain text suitable for snippets.
    # Handles links, images, bold/italic, code blocks, blockquotes, lists,
    # heading anchors, and HTML tags.
    def clean_markdown(text)
      text
        .gsub(/!\[([^\]]*)\]\([^)]*\)/, '\1')   # Images: ![alt](url) → alt
        .gsub(/\[([^\]]*)\]\([^)]*\)/, '\1')     # Links: [text](url) → text
        .gsub(/^\#{1,6}\s+/, "")                  # Heading markers
        .gsub(/\{#[\w-]+\}/, "")                  # Anchor tags {#id}
        .gsub(/```.*?```/m, "")                   # Fenced code blocks
        .gsub(/~~~.*?~~~/m, "")                   # Tilde code blocks
        .gsub(/`([^`]*)`/, '\1')                  # Inline code
        .gsub(/\*\*([^*]*)\*\*/, '\1')            # Bold
        .gsub(/__([^_]*)__/, '\1')                # Bold (underscores)
        .gsub(/\*([^*]*)\*/, '\1')                # Italic
        .gsub(/_([^_]*)_/, '\1')                  # Italic (underscores)
        .gsub(/~~([^~]*)~~/, '\1')                # Strikethrough
        .gsub(/^>\s?/, "")                        # Blockquotes
        .gsub(/^[-*+]\s/, "")                     # Unordered list markers
        .gsub(/^\d+\.\s/, "")                     # Ordered list markers
        .gsub(/<[^>]+>/, "")                      # HTML tags
        .gsub(/\n{2,}/, "\n")                     # Collapse multiple newlines
        .strip
    end

    # Build a snippet of ~SNIPPET_LENGTH chars from section text, centered
    # around the first occurrence of any search term.
    def build_snippet(section, terms)
      raw = section[:raw_text]
      return "" if raw.blank?

      normalized = section[:normalized_text]
      return raw.truncate(SNIPPET_LENGTH) if normalized.blank?

      # Find the position of the first matching term in normalized text
      first_pos = nil
      terms.each do |term|
        pos = normalized.index(term)
        first_pos = pos if pos && (first_pos.nil? || pos < first_pos)
      end

      return raw.truncate(SNIPPET_LENGTH) unless first_pos

      # Map position from normalized text to raw text using index ratio.
      # This is approximate but good enough for snippet centering.
      ratio = raw.length.to_f / normalized.length
      raw_pos = (first_pos * ratio).round.clamp(0, raw.length - 1)

      # Center the snippet window around the match
      half = SNIPPET_LENGTH / 2
      start_pos = [ raw_pos - half, 0 ].max
      end_pos = [ start_pos + SNIPPET_LENGTH, raw.length ].min
      start_pos = [ end_pos - SNIPPET_LENGTH, 0 ].max

      snippet = raw[start_pos...end_pos]

      # Add ellipsis if we're not at the boundaries
      snippet = "…#{snippet}" if start_pos > 0
      snippet = "#{snippet}…" if end_pos < raw.length

      snippet
    end
  end
end
