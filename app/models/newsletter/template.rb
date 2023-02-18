class Newsletter
  class Template < ApplicationRecord
    self.table_name = 'newsletter_templates'

    DEFAULTS = %w[simple next_delivery].freeze

    include TranslatedAttributes
    include Auditable
    include Liquidable

    attr_accessor :no_preview

    has_many :newsletters, foreign_key: 'newsletter_template_id'

    audited_attributes :contents

    translated_attributes :content, required: true

    validates :title, presence: true, uniqueness: true
    validate :contents_must_be_valid
    validate :content_block_ids_must_be_unique
    validate :content_block_ids_must_be_equal_for_all_languages

    def self.create_defaults!
      DEFAULTS.each do |key|
        title = I18n.with_locale(Current.acp.default_locale) {
          I18n.t("newsletters.template.#{key}.title")
        }
        contents = Current.acp.languages.reduce({}) { |h, l|
          path = Rails.root.join("app/views/newsletter_templates/#{key}.#{l}.liquid")
          h[l] = File.read(path)
          h
        }
        create!(title: title, contents: contents)
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
        [locale, data]
      }.to_h
    end

    def liquid_data_preview_yamls
      Current.acp.languages.map { |locale|
        data =
          @liquid_data_previews&.dig(locale) ||
            I18n.with_locale(locale) {
              Liquid::DataPreview.for(self).merge(
                'subject' => I18n.t('newsletters.template.subject'))
            }
        [locale, data.to_yaml(line_width: -1).gsub("---\n", '')]
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
      Current.acp.languages.map { |locale|
        blocks = I18n.with_locale(locale) {
          Liquid::Template.parse(content).root.nodelist.select { |node|
            node.class.to_s == 'Liquid::ContentBlock'
          }
        }
        [locale, blocks]
      }.to_h
    end

    def content_block_ids
      @content_block_ids ||=
        content_blocks.flat_map { |_locale, blocks| blocks.map(&:id) }.uniq
    end

    def blocks
      content_block_ids.map { |block_id|
        Newsletter::Block.new(
          block_id: block_id,
          template_id: id,
          contents: content_blocks.map { |locale, blocks|
            block = blocks.find { |b| b.id == block_id }
            [locale, block.raw_body]
          }.to_h,
          titles: content_blocks.map { |locale, blocks|
            block = blocks.find { |b| b.id == block_id }
            [locale, block.title]
          }.to_h)
      }
    end

    def mailer_preview; NewsletterMailerPreview end
    def email_method; :newsletter_email end

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
      Current.acp.languages.each do |locale|
        ids = content_blocks[locale].map(&:id)
        if ids.uniq.size != ids.size
          errors.add("content_#{locale}".to_sym, :content_block_ids_must_be_unique)
        end
      end
    rescue Liquid::SyntaxError
    end

    def content_block_ids_must_be_equal_for_all_languages
      return unless Current.acp.languages.many?

      Current.acp.languages.each do |locale|
        ids = content_blocks[locale].map(&:id)
        if ids != content_block_ids
          errors.add("content_#{locale}".to_sym, :content_block_ids_must_be_equal_for_all_languages)
        end
      end
    rescue Liquid::SyntaxError
    end
  end
end
