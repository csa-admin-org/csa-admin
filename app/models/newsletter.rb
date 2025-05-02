# frozen_string_literal: true

class Newsletter < ApplicationRecord
  include TranslatedAttributes
  include Auditable
  include Liquidable
  include HasAttachments

  MISSING_DELIVERY_EMAILS_ALLOWED_PERIOD = 1.week

  translated_attributes :audience_name
  translated_attributes :signature
  translated_attributes :subject, required: true

  audited_attributes :sent_at, :scheduled_at

  belongs_to :template,
    class_name: "Newsletter::Template",
    foreign_key: "newsletter_template_id"
  has_many :blocks, class_name: "Newsletter::Block", dependent: :destroy
  has_many :deliveries, class_name: "Newsletter::Delivery", dependent: :delete_all
  has_many :members, -> { distinct }, through: :deliveries

  accepts_nested_attributes_for :blocks, allow_destroy: true

  scope :draft, -> { where(sent_at: nil, scheduled_at: nil) }
  scope :scheduled, -> { where(sent_at: nil).where.not(scheduled_at: nil) }
  scope :schedulable, -> { scheduled.where(scheduled_at: ..Time.current) }
  scope :sent, -> { where.not(sent_at: nil) }

  validates :audience, presence: true
  validate :subjects_must_be_valid
  validate :at_least_one_block_must_be_present
  validates :scheduled_at,
    date: { after: proc { Date.today } },
    allow_nil: true,
    if: :scheduled_at_changed?
  validates :from, format: {
    with: ->(n) { /.*@#{Tenant.domain}\z/ },
    allow_nil: true
  }

  after_save_commit :save_draft_deliveries!

  def from=(value)
    self[:from] = value.presence
  end

  def display_name
    "##{id} #{subject}"
  end

  def tag
    "newsletter-#{id}"
  end

  def state
    if processing_delivery?
      "processing"
    elsif sent?
      "sent"
    elsif scheduled?
      "scheduled"
    else
      "draft"
    end
  end

  def scheduled?
    scheduled_at?
  end

  def unschedule!
    update_columns(scheduled_at: nil)
  end

  def audience_segment
    @audience_segment ||= Audience::Segment.parse(audience)
  end

  def audience_name
    if sent?
      audience_name_with_fallback.html_safe
    else
      Audience.name(audience_segment).html_safe
    end
  end

  def signatures
    self[:signatures].presence || Current.org.email_signatures
  end

  def sent?
    sent_at?
  end

  def sent_by
    audits.find_change_of(:sent_at, from: nil)&.actor
  end

  def processing_delivery?
    deliveries.processing.any?
  end

  def template_contents
    if sent?
      super
    else
      template.liquid_data_preview_yamls = liquid_data_preview_yamls
      template.contents
    end
  end

  def send!
    raise "Already sent!" if sent?

    transaction do
      self[:liquid_data_preview_yamls] = liquid_data_preview_yamls
      set_audience_names
      self.template_contents = template.contents
      self.sent_at = Time.current
      save!
      create_deliveries!(draft: false)
    end
  end

  def save_draft_deliveries!
    return if sent?

    create_deliveries!(draft: true)
  end

  # Allow to already sent newsletter to a new email address
  def deliver!(email)
    return unless sent?
    return unless missing_delivery_emails.include?(email)

    member = Member.find_by_email(email)
    Delivery.create_for!(self, member, draft: false, email: email)
  end

  def mail_preview(locale)
    if sent?
      template.contents = template_contents
      template.liquid_data_preview_yamls = self[:liquid_data_preview_yamls]
    else
      template.liquid_data_preview_yamls = liquid_data_preview_yamls
    end
    mailer_preview.call(email_method,
      template: template,
      subject: subject(locale).to_s,
      blocks: relevant_blocks,
      signature: signature_without_fallback(locale),
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
      data =
        @liquid_data_previews&.dig(locale) ||
          I18n.with_locale(locale) { Liquid::DataPreview.for(self) }
      [ locale, data.to_yaml(line_width: -1).gsub("---\n", "") ]
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
    !sent? && audience_segment.emails.size.positive?
  end

  def show_missing_delivery_emails?
    missing_delivery_emails_allowed? && missing_delivery_emails?
  end

  def missing_delivery_emails_allowed?
    sent? && sent_at > MISSING_DELIVERY_EMAILS_ALLOWED_PERIOD.ago
  end

  def missing_delivery_emails?
    missing_delivery_emails.any?
  end

  def missing_delivery_emails
    audience_segment.emails - deliveries.pluck(:email)
  end

  private

  def subjects_must_be_valid
    validate_liquid(:subjects)
    validate_html(:subjects)
  end

  def at_least_one_block_must_be_present
    if relevant_blocks.none?(&:any_contents?)
      errors.add(:blocks, :empty)
    end
  end

  def set_audience_names
    Current.org.languages.each do |locale|
      I18n.with_locale(locale) do
        self.send "audience_name_#{locale}=", Audience.name(audience_segment)
      end
    end
  end

  def create_deliveries!(draft:)
    transaction do
      deliveries.delete_all
      audience_segment.members.each do |member|
        Delivery.create_for!(self, member, draft: draft)
      end
    end
  end
end
