# frozen_string_literal: true

module Handbook::Search
  extend ActiveSupport::Concern

  # Heading lines are plain text (no ERB), so regex is safe.
  H1_REGEX = /^#\s+(.+?)$/
  H2_REGEX = /^##\s+(.+?)\s*\{#([\w-]+)\}$/
  H3_REGEX = /^###\s+(.+?)\s*\{#([\w-]+)\}$/

  SNIPPET_LENGTH = 120
  MAX_CONTENT_RESULTS = 10

  class_methods do
    def search(query, locale: I18n.locale)
      query = query.to_s.strip
      return [] if query.length < 2

      terms = SearchEntry.search_terms(query)
      return [] if terms.empty?

      results = []

      headings_for(locale).each do |page|
        next if Organization.restricted_features.include?(page[:name].to_sym)
        next if Current.org.inactive_feature?(page[:name])
        next if Handbook::DEMO_ONLY_PAGES.include?(page[:name].to_sym) && !Tenant.demo?

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

      results.sort_by { |r| r[:subtitle] ? 1 : 0 }
    end

    def content_search(query, locale: I18n.locale)
      query = query.to_s.strip
      return [] if query.length < 3

      terms = SearchEntry.search_terms(query)
      return [] if terms.empty?

      results = []

      pages_for(locale).each do |page|
        next if Organization.restricted_features.include?(page[:name].to_sym)
        next if Handbook::DEMO_ONLY_PAGES.include?(page[:name].to_sym) && !Tenant.demo?

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

        heading_results = []
        best_body_result = nil

        page[:sections].each do |section|
          heading_match = section[:normalized_heading] &&
            terms.all? { |term| section[:normalized_heading].include?(term) }

          body_match = terms.all? { |term| section[:normalized_text].include?(term) }

          if heading_match
            heading_results << {
              name: page[:name],
              title: page[:title],
              heading: section[:heading],
              anchor: section[:anchor],
              snippet: build_snippet(section, terms),
              rank: 1
            }
          elsif body_match && best_body_result.nil?
            best_body_result = {
              name: page[:name],
              title: page[:title],
              heading: section[:heading],
              anchor: section[:anchor],
              snippet: build_snippet(section, terms),
              rank: 2
            }
          end
        end

        if heading_results.any?
          results.concat(heading_results)
        elsif best_body_result
          results << best_body_result
        end
      end

      results
        .sort_by { |r| r[:rank] }
        .first(MAX_CONTENT_RESULTS)
        .map { |r| r.except(:rank) }
    end

    # Cached per locale + country_code; content is static (changes on deploy/restart).
    def headings_for(locale)
      @headings ||= {}
      cache_key = :"#{locale}_#{Current.org.country_code}"
      @headings[cache_key] ||= parse_headings(locale)
    end

    def clear_headings_cache!
      @headings = {}
    end

    def pages_for(locale)
      @pages ||= {}
      cache_key = :"#{locale}_#{Current.org.country_code}"
      @pages[cache_key] ||= parse_pages(locale)
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
        content = Handbook.filter_country_sections(content)

        title = content[H1_REGEX, 1]
        next unless title

        subtitles = (content.scan(H2_REGEX) + content.scan(H3_REGEX)).map { |text, anchor|
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

    def parse_pages(locale)
      path = Rails.root.join(Handbook::DIR_PATH, "*.#{locale}.md.erb")
      Dir.glob(path).filter_map { |filepath|
        name = File.basename(filepath, ".#{locale}.md.erb")
        content = File.read(filepath)
        content = Handbook.filter_country_sections(content)

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

    def strip_erb_tags(text)
      text.gsub(/<%=?.*?%>/m, "")
    end

    def split_into_sections(content)
      content = content.sub(H1_REGEX, "").lstrip

      parts = content.split(/^(?=##\s)/)
      parts.flat_map { |part|
        heading_match = part.match(H2_REGEX)
        if heading_match
          heading = heading_match[1]
          anchor = heading_match[2]
          body = part.sub(H2_REGEX, "").strip
        else
          heading = nil
          anchor = nil
          body = part.strip
        end

        raw_text = clean_markdown(body)

        h2_section = {
          heading: heading,
          anchor: anchor,
          normalized_heading: heading ? SearchEntry.normalize_text(heading) : nil,
          raw_text: raw_text,
          normalized_text: SearchEntry.normalize_text(raw_text)
        }

        # Extract H3 sub-sections so they are individually searchable
        h3_sections = body.scan(H3_REGEX).map { |h3_text, h3_anchor|
          {
            heading: h3_text,
            anchor: h3_anchor,
            normalized_heading: SearchEntry.normalize_text(h3_text),
            raw_text: raw_text,
            normalized_text: SearchEntry.normalize_text(raw_text)
          }
        }

        [ h2_section ] + h3_sections
      }
    end

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

    def build_snippet(section, terms)
      raw = section[:raw_text]
      return "" if raw.blank?

      normalized = section[:normalized_text]
      return raw.truncate(SNIPPET_LENGTH) if normalized.blank?

      first_pos = nil
      terms.each do |term|
        pos = normalized.index(term)
        first_pos = pos if pos && (first_pos.nil? || pos < first_pos)
      end

      return raw.truncate(SNIPPET_LENGTH) unless first_pos

      ratio = raw.length.to_f / normalized.length
      raw_pos = (first_pos * ratio).round.clamp(0, raw.length - 1)

      half = SNIPPET_LENGTH / 2
      start_pos = [ raw_pos - half, 0 ].max
      end_pos = [ start_pos + SNIPPET_LENGTH, raw.length ].min
      start_pos = [ end_pos - SNIPPET_LENGTH, 0 ].max

      snippet = raw[start_pos...end_pos]

      snippet = "…#{snippet}" if start_pos > 0
      snippet = "#{snippet}…" if end_pos < raw.length

      snippet
    end
  end
end
