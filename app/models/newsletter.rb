class Newsletter < ApplicationRecord
  include TranslatedAttributes
  include Auditable

  ATTACHMENTS_MAXIMUM_SIZE = 5.megabytes

  translated_attributes :subject, required: true

  audited_attributes :sent_at

  belongs_to :template,
    class_name: 'Newsletter::Template',
    foreign_key: 'newsletter_template_id'
  has_many :blocks, class_name: 'Newsletter::Block', dependent: :destroy
  has_many :attachments, class_name: 'Newsletter::Attachment', dependent: :destroy
  has_many :deliveries, class_name: 'Newsletter::Delivery'
  has_many :members, through: :deliveries

  accepts_nested_attributes_for :blocks, :attachments, allow_destroy: true

  scope :draft, -> { where(sent_at: nil) }
  scope :sent, -> { where.not(sent_at: nil) }

  validates :audience, presence: true
  validate :at_least_one_block_must_be_present
  validate :same_blocks_must_be_present_for_all_languages
  validate :attachments_must_not_exceed_maximum_size

  def audience_segment
    @audience_segment ||= Audience::Segment.parse(audience)
  end

  def members_count
    @members_count ||= if sent?
      members.count
    else
      audience_segment.members.count
    end
  end

  def emails
    @member_emails ||= if sent?
      deliveries.pluck(:emails).flatten
    else
      audience_segment.emails
    end
  end

  def suppressed_emails
    @suppressed_emails ||= if sent?
      deliveries.pluck(:suppressed_emails).flatten
    else
      audience_segment.suppressed_emails
    end
  end

  def sent?
    sent_at?
  end

  def sent_by
    audits.find_change_of(:sent_at, from: nil)&.actor
  end

  def ongoing_delivery?
    deliveries.undelivered.any?
  end

  def send!
    raise 'Already sent!' if sent?

    transaction do
      update!(
        template_contents: template.contents,
        sent_at: Time.current)
      audience_segment.members.each do |member|
        deliveries.create!(member: member)
      end
    end
    Newsletter::DeliveryJob.set(wait: 10).perform_later(self)
  end

  def mail_preview(locale)
    template.liquid_data_preview_yamls = liquid_data_preview_yamls
    template.contents = template_contents if sent?
    mailer_preview.call(email_method,
      template: template,
      subject: subject(locale).to_s,
      blocks: relevant_blocks,
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

  def relevant_blocks
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

  def can_send_email?
    !sent? && emails.size.positive?
  end

  private

  def at_least_one_block_must_be_present
    if relevant_blocks.none?(&:any_contents?)
      errors.add(:blocks, :empty)
    end
  end

  def same_blocks_must_be_present_for_all_languages
    relevant_blocks.each do |block|
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

  def attachments_must_not_exceed_maximum_size
    if attachments.sum { |a| a.file.byte_size } > ATTACHMENTS_MAXIMUM_SIZE
      errors.add(:attachments, :too_large)
    end
  end
end
