# frozen_string_literal: true

require "digest"

class Newsletter
  # Builds the public, member-free projection of a newsletter for Atom publication.
  class PublicProjection
    class Error < StandardError; end

    # Rails safe list + Action Text/Trix extras used in newsletter blocks.
    ALLOWED_TAGS = (
      Rails::HTML4::Sanitizer.safe_list_sanitizer.allowed_tags.to_a +
      %w[figure figcaption table thead tbody tr th td u s]
    ).uniq.freeze

    ALLOWED_ATTRIBUTES = (
      Rails::HTML4::Sanitizer.safe_list_sanitizer.allowed_attributes.to_a +
      %w[id loading]
    ).uniq.freeze

    SUMMARY_LENGTH = 280

    def self.payload_for(newsletter)
      Current.org.languages.each_with_object({}) { |locale, payloads|
        projection = new(newsletter, locale: locale)
        next if projection.empty?

        payloads[locale.to_s] = projection.locale_payload
      }
    end

    def self.content_digest_for(payload)
      Digest::SHA256.hexdigest(canonical_payload(payload))
    end

    def self.canonical_payload(payload)
      locales = payload.except("attachments")
      locales_canonical = locales
        .sort_by { |locale, _| locale.to_s }
        .map { |locale, data|
          [
            locale.to_s,
            data["title"].to_s,
            data["summary"].to_s,
            *Array(data["sections"]).map { |section|
              [ section["id"], section["title"].to_s, section["html"].to_s ].join("\n")
            }
          ].join("\n---\n")
        }.join("\n===\n")

      attachments_canonical = Array(payload["attachments"]).map { |attachment|
        [
          attachment["filename"].to_s,
          attachment["content_type"].to_s,
          attachment["byte_size"].to_s,
          attachment["signed_id"].to_s
        ].join("\n")
      }.join("\n---\n")

      [ locales_canonical, attachments_canonical ].reject(&:blank?).join("\n###\n")
    end

    def initialize(newsletter, locale: nil)
      @newsletter = newsletter
      @locale = (locale || Current.org.default_locale || Current.org.languages.first).to_s
    end

    def empty?
      sections.empty?
    end

    def locale_payload
      {
        "title" => title,
        "summary" => summary,
        "sections" => sections
      }
    end

    # Single-locale payload (used by draft validation and tests).
    def payload
      locale_payload
    end

    def title
      @title ||= render_liquid(subject_source, context: liquid_data).strip
    end

    def summary
      @summary ||= begin
        plain = sections.filter_map { |section|
          plain_text(section["html"]).presence
        }.join(" ").squish
        plain.truncate(SUMMARY_LENGTH)
      end
    end

    def sections
      @sections ||= public_content_blocks.filter_map { |block_node|
        newsletter_block = newsletter_blocks_by_id[block_node.id]
        next unless newsletter_block

        html_source = block_html_source(newsletter_block)
        next if html_source.blank?

        rendered = render_liquid(html_source, context: liquid_data)
        sanitized = sanitize_html(rendered)
        next if plain_text(sanitized).blank? && !sanitized.include?("<img")

        {
          "id" => block_node.id,
          "title" => block_node.title.to_s.presence,
          "html" => sanitized
        }
      }
    end

    def public_content_blocks
      @public_content_blocks ||= begin
        template_liquid = frozen_template_content
        return [] if template_liquid.blank?

        nodes = Liquid::Template.parse(template_liquid).root.nodelist.select { |node|
          node.is_a?(Liquid::ContentBlock)
        }
        nodes.select(&:public?)
      rescue Liquid::Error => e
        raise Error, e.message
      end
    end

    private

    def frozen_template_content
      contents =
        if @newsletter.sent?
          @newsletter[:template_contents]
        else
          @newsletter.template.contents
        end
      contents[@locale].presence || contents.values.first
    end

    def subject_source
      subjects = @newsletter.subjects || {}
      subjects[@locale].presence || subjects.values.first.to_s
    end

    def newsletter_blocks_by_id
      # Use the AR association, not Newsletter#blocks (template-merged override).
      @newsletter_blocks_by_id ||=
        @newsletter.association(:blocks).load_target.index_by(&:block_id)
    end

    def block_html_source(block)
      I18n.with_locale(@locale) do
        rich_text = block.send("rich_text_content_#{@locale}")
        return "" if rich_text.blank?

        plain = rich_text.to_plain_text.to_s.strip
        html = ActionTextHtml.unwrap_attachments(rich_text.to_s)
        return "" if plain.blank? && !html.match?(/<img\b/i)

        html
      end
    end

    def liquid_data
      @liquid_data ||= {
        "organization" => Liquid::PublicOrganizationDrop.new(Current.org),
        "today" => I18n.with_locale(@locale) { I18n.l(Date.current) }
      }
    end

    def render_liquid(source, context:)
      template = Liquid::Template.parse(source.to_s)
      template.render!(context.stringify_keys, strict_variables: true, strict_filters: true)
    rescue Liquid::UndefinedVariable, Liquid::UndefinedFilter, Liquid::SyntaxError, Liquid::Error => e
      raise Error, e.message
    end

    def sanitize_html(html)
      ActionController::Base.helpers.sanitize(
        html.to_s,
        tags: ALLOWED_TAGS,
        attributes: ALLOWED_ATTRIBUTES)
    end

    def plain_text(html)
      ActionController::Base.helpers.strip_tags(html.to_s).squish
    end
  end
end
