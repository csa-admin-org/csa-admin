# frozen_string_literal: true

class Newsletter
  class Template < ApplicationRecord
    self.table_name = "newsletter_templates"

    DEFAULTS = %w[simple next_delivery].freeze

    include TranslatedAttributes
    include Auditable
    include Liquidable

    attr_accessor :no_preview

    has_many :newsletters, foreign_key: "newsletter_template_id"
    has_many :publications,
      class_name: "Newsletter::Publication",
      foreign_key: "newsletter_template_id",
      dependent: :restrict_with_exception

    audited_attributes :contents

    translated_attributes :title, required: true
    translated_attributes :content, required: true

    validate :contents_must_be_valid
    validate :content_block_ids_must_be_unique
    validate :content_block_ids_must_be_equal_for_all_languages
    validate :feed_enabled_requires_public_content_block

    def self.create_defaults!
      DEFAULTS.each do |key|
        titles = Organization.languages.index_with { |l|
          I18n.with_locale(l) { I18n.t("newsletters.template.#{key}.title") }
        }
        contents = Organization.languages.index_with { |l|
          LiquidErb.render("newsletter_templates/#{key}", locale: l)
        }
        create!(titles: titles, contents: contents)
      end
    end

    def mail_preview(locale)
      mailer_preview.call(email_method,
        template: self,
        blocks: blocks,
        locale: locale
      ).html_part.body.encoded
    rescue => e
      e.message
    end

    def liquid_data_preview_yamls=(hash)
      @liquid_data_previews = hash.map { |locale, yaml|
        data = begin
          YAML.load("---\n#{yaml}")
        rescue
        end
        [ locale, data ]
      }.to_h
    end

    def liquid_data_preview_yamls
      Current.org.languages.map { |locale|
        data = @liquid_data_previews&.dig(locale)
          || I18n.with_locale(locale) {
            Liquid::DataPreview.for(self).merge(
              "subject" => I18n.t("newsletters.template.subject"))
          }
        [ locale, data.to_yaml(line_width: -1).gsub("---\n", "") ]
      }.to_h
    end

    def liquid_data_preview
      return if no_preview

      unless @liquid_data_previews
        self.liquid_data_preview_yamls = liquid_data_preview_yamls
      end
      @liquid_data_previews&.dig(I18n.locale.to_s)
    end

    def content_blocks
      Current.org.languages.map { |locale|
        blocks = I18n.with_locale(locale) {
          Liquid::Template.parse(content).root.nodelist.select { |node|
            node.class.to_s == "Liquid::ContentBlock"
          }
        }
        [ locale, blocks ]
      }.to_h
    end

    def content_block_ids
      @content_block_ids ||=
        content_blocks.flat_map { |_locale, blocks| blocks.map(&:id) }.uniq
    end

    def public_content_block_ids
      content_blocks.flat_map { |_locale, blocks|
        blocks.select(&:public?).map(&:id)
      }.uniq
    end

    def self.members_feed_host
      host = Tenant.members_host
      if Rails.env.local?
        # Match ApplicationMailer#mailer_host: production TLD → .test
        # e.g. membres.ragedevert.ch → membres.ragedevert.test
        parsed = PublicSuffix.parse(host)
        host = [ parsed.trd, parsed.sld, "test" ].compact.join(".")
      end
      host
    end

    def feed_url
      return unless feed_enabled?

      Rails.application.routes.url_helpers.members_newsletter_feed_url(
        host: self.class.members_feed_host,
        protocol: "https",
        template_id: id)
    end

    def blocks
      content_blocks_by_locale = content_blocks
      block_ids =
        @content_block_ids ||=
          content_blocks_by_locale.flat_map { |_locale, blocks| blocks.map(&:id) }.uniq

      block_ids.map { |block_id|
        locale_blocks = content_blocks_by_locale.map { |locale, blocks|
          [ locale, blocks.find { |b| b.id == block_id } ]
        }
        Newsletter::Block.new(
          block_id: block_id,
          template_id: id,
          public_content: locale_blocks.any? { |_locale, block| block&.public? },
          public_feed: feed_enabled?,
          contents: locale_blocks.to_h { |locale, block| [ locale, block&.raw_body ] },
          titles: locale_blocks.to_h { |locale, block| [ locale, block&.title ] })
      }
    end

    def mailer_preview; NewsletterMailerPreview end
    def email_method; :newsletter_email end
    def tag; nil end

    def can_update?; true end
    def can_destroy?
      newsletters.none?
    end

    private

    def contents_must_be_valid
      validate_liquid(:contents)
      validate_html(:contents)
    end

    def content_block_ids_must_be_unique
      Current.org.languages.each do |locale|
        ids = content_blocks[locale].map(&:id)
        if ids.uniq.size != ids.size
          errors.add("content_#{locale}".to_sym, :content_block_ids_must_be_unique)
        end
      end
    rescue Liquid::SyntaxError
    end

    def content_block_ids_must_be_equal_for_all_languages
      return unless Current.org.languages.many?

      Current.org.languages.each do |locale|
        ids = content_blocks[locale].map(&:id)
        if ids != content_block_ids
          errors.add("content_#{locale}".to_sym, :content_block_ids_must_be_equal_for_all_languages)
        end
      end
    rescue Liquid::SyntaxError
    end

    def feed_enabled_requires_public_content_block
      return unless feed_enabled?

      if public_content_block_ids.empty?
        errors.add(:feed_enabled, :requires_public_content_block)
      end
    rescue Liquid::SyntaxError
    end
  end
end
