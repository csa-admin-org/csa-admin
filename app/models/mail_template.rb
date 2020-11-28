class MailTemplate < ApplicationRecord
  include TranslatedAttributes
  include Auditable

  MEMBER_TITLES = %w[
    member_validated
    member_activated
  ].freeze
  INVOICE_TITLES = %w[
    invoice_created
    invoice_overdue_notice
  ].freeze
  ACTIVITY_TITLES = %w[
    activity_participation_reminder
    activity_participation_validated
    activity_participation_rejected
  ].freeze
  TITLES = MEMBER_TITLES + INVOICE_TITLES + ACTIVITY_TITLES

  audited_attributes :subjects, :contents

  translated_attributes :subject, :content
  validates :title,
    presence: true,
    inclusion: { in: TITLES },
    uniqueness: true
  validate :subjects_must_be_present, :contents_must_be_present
  validate :subjects_must_be_valid, :contents_must_be_valid
  validates :active, inclusion: [true], if: :always_active?

  after_initialize :set_defaults

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :member, -> { where(title: MEMBER_TITLES) }
  scope :invoice, -> { where(title: INVOICE_TITLES) }
  scope :activity, -> { where(title: ACTIVITY_TITLES) }

  def self.deliver_now(title, **args)
    active_template(title)&.mail(**args)&.deliver_now
  end

  def self.deliver_later(title, **args)
    active_template(title)&.mail(**args)&.deliver_later
  end

  def self.active_template(title)
    active.find_by(title: title)
  end

  def self.create_all!
    TITLES.each do |title|
      find_or_create_by!(title: title)
    end
  end

  def mail(**args)
    args[:template] = self
    mailer.with(**args).send(email_method)
  end

  def mail_preview(locale)
    mailer_preview.call(email_method,
      template: self,
      locale: locale
    ).html_part.body.encoded
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
    @liquid_data_previews&.dig(I18n.locale.to_s)
  end

  def to_param
    title
  end

  def display_name
    I18n.t("mail_template.title.#{title}")
  end

  def description
    I18n.t("mail_template.description.#{title}")
  end

  def mailer
    "#{title.split('_').first}_mailer".classify.constantize
  end

  def mailer_preview
    "#{title.split('_').first}_mailer_preview".classify.constantize
  end

  def email_method
    "#{title.split('_').drop(1).join('_')}_email"
  end

  def contents=(hash)
    super hash.transform_values { |v| v.strip + "\n" }
  end

  def always_active?
    title.in?(INVOICE_TITLES + ACTIVITY_TITLES)
  end

  private

  def subjects_must_be_present
    Current.acp.languages.each do |locale|
      errors.add("subject_#{locale}".to_sym, :blank) if subjects[locale].blank?
    end
  end

  def contents_must_be_present
    Current.acp.languages.each do |locale|
      errors.add("content_#{locale}".to_sym, :blank) if contents[locale].blank?
    end
  end

  def subjects_must_be_valid
    validate_liquid(:subjects)
  end

  def contents_must_be_valid
    validate_liquid(:contents)
    validate_html(:contents)
  end

  def validate_liquid(attr)
    Current.acp.languages.each do |locale|
      Liquid::Template.parse(send(attr)[locale])
    rescue Liquid::SyntaxError => e
      errors.add("#{attr.to_s.singularize}_#{locale}".to_sym, e.message)
    end
  end

  def validate_html(attr)
    Current.acp.languages.each do |locale|
      doc = Nokogiri::HTML5.fragment(send(attr)[locale], max_errors: 10)
      doc.errors.each do |err|
        errors.add(
          "#{attr.to_s.singularize}_#{locale}".to_sym,
          "HTML error at line #{err.line}: #{err.str1.underscore.humanize}")
      end
    end
  end

  def set_defaults
    self.active = always_active? if new_record?
    self.subjects = default_subjects
    self.contents = default_contents
  end

  def default_subjects
    ACP.languages.reduce({}) do |h, locale|
      h[locale] = subjects[locale] || I18n.with_locale(locale) {
        I18n.t("mail_template.default_subjects.#{title}")
      }
      h
    end
  end

  def default_contents
    ACP.languages.reduce({}) do |h, locale|
      path = Rails.root.join("app/views/mail_templates/#{title}.#{locale}.liquid")
      h[locale] ||= contents[locale] || File.read(path)
      h
    end
  end
end

Liquid::Template.register_tag('button', Liquid::ButtonBlock)
Liquid::Template.register_tag('highlight', Liquid::HighlightBlock)
Liquid::Template.register_tag('highlight_list', Liquid::HighlightListBlock)
