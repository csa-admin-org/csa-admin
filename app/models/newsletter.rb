class Newsletter < ApplicationRecord
  include TranslatedAttributes

  translated_attributes :subject, required: true

  belongs_to :template,
    class_name: 'Newsletter::Template',
    foreign_key: 'newsletter_template_id'
  has_many :blocks, class_name: 'Newsletter::Block', dependent: :destroy

  accepts_nested_attributes_for :blocks, allow_destroy: true

  scope :draft, -> { where(sent_at: nil) }
  scope :sent, -> { where.not(sent_at: nil) }

  validates :audience, presence: true
  validate :at_least_one_block_must_be_present
  validate :same_blocks_must_be_present_for_all_languages

  def audience_segment
    @audience_segment ||= Audience::Segment.parse(audience)
  end

  def members_count
    @members_count ||= audience_segment.members.count
  end

  def sent?
    sent_at?
  end

  def mail_preview(locale)
    template.liquid_data_preview_yamls = liquid_data_preview_yamls
    mailer_preview.call(email_method,
      template: template,
      subject: subject(locale).to_s,
      blocks: template_blocks,
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
          I18n.with_locale(locale) { Liquid::DataPreview.for(self) }
      [locale, data.to_yaml(line_width: -1).gsub("---\n", '')]
    }.to_h
  end

  def liquid_data_preview
    unless @liquid_data_previews
      self.liquid_data_preview_yamls = liquid_data_preview_yamls
    end
    @liquid_data_previews&.dig(I18n.locale.to_s)
  end

  def mailer_preview; NewsletterMailerPreview end
  def email_method; :newsletter_email end

  def template_blocks
    blocks.select { |b| b.template_id == template.id }
  end

  def blocks
    @blocks ||= begin
      blocks = super
      Newsletter::Template.all.flat_map(&:blocks).map do |t_block|
        if block = blocks.find { |b| b.block_id == t_block.block_id }
          t_block.contents = block.contents
          if t_block.template_id == newsletter_template_id
            t_block.id = block.id
          end
        end
        t_block
      end
    end
  end

  def can_destroy?
    !sent?
  end

  def can_update?
    !sent?
  end

  private

  def at_least_one_block_must_be_present
    if template_blocks.none?(&:any_contents?)
      errors.add(:blocks, :empty)
    end
  end

  def same_blocks_must_be_present_for_all_languages
    template_blocks.each do |block|
      if block.any_contents? && !block.all_contents?
        block.contents.each do |locale, content|
          if content.to_plain_text.blank?
            block.errors.add("content_#{locale}", :empty)
            errors.add(:blocks, :empty)
          end
        end
      end
    end
  end
end
