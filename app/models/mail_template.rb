# frozen_string_literal: true

class MailTemplate < ApplicationRecord
  include TranslatedAttributes
  include Auditable
  include Liquidable

  MEMBER_TITLES = %w[
    member_validated
    member_activated
  ].freeze
  MEMBERSHIP_TITLES = %w[
    membership_initial_basket
    membership_final_basket
    membership_first_basket
    membership_last_basket
    membership_second_last_trial_basket
    membership_last_trial_basket
    membership_renewal
    membership_renewal_reminder
  ].freeze
  ABSENCE_TITLES = %w[
    absence_created
    absence_basket_shifted
    absence_included_reminder
  ].freeze
  ACTIVITY_TITLES = %w[
    activity_participation_reminder
    activity_participation_validated
    activity_participation_rejected
  ].freeze
  BIDDING_ROUND_TITLES = %w[
    bidding_round_opened
    bidding_round_opened_reminder
    bidding_round_completed
    bidding_round_failed
  ].freeze
  INVOICE_TITLES = %w[
    invoice_created
    invoice_cancelled
    invoice_overdue_notice
  ].freeze
  TITLES = MEMBER_TITLES + MEMBERSHIP_TITLES + ABSENCE_TITLES + ACTIVITY_TITLES + BIDDING_ROUND_TITLES + INVOICE_TITLES
  ALWAYS_ACTIVE_TITLES = %w[
    invoice_created
    absence_included_reminder
    activity_participation_reminder
  ]
  ACTIVE_BY_DEFAULT_TITLES = ALWAYS_ACTIVE_TITLES + %w[
    invoice_overdue_notice
    bidding_round_opened
    bidding_round_opened_reminder
    bidding_round_completed
    bidding_round_failed
  ]
  TITLES_WITH_DELIVERY_CYCLES_SCOPE = MEMBERSHIP_TITLES - %w[
    membership_renewal
    membership_renewal_reminder
  ].freeze

  audited_attributes :subjects, :contents

  translated_attributes :subject, :content, required: true
  validates :title,
    presence: true,
    inclusion: { in: TITLES },
    uniqueness: true
  validates :delivery_cycle_ids, presence: true, if: :active?
  validate :subjects_must_be_valid, :contents_must_be_valid

  after_initialize :set_defaults

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :member, -> { where(title: MEMBER_TITLES) }
  scope :membership, -> { where(title: MEMBERSHIP_TITLES) }
  scope :absence, -> { where(title: ABSENCE_TITLES) }
  scope :activity, -> { where(title: ACTIVITY_TITLES) }
  scope :bidding_round, -> { where(title: BIDDING_ROUND_TITLES) }
  scope :invoice, -> { where(title: INVOICE_TITLES) }

  def self.deliver_now(title, **args)
    active_template(title)&.mail(**args)&.deliver_now
  end

  def self.deliver_later(title, wait: 5.seconds, **args)
    later_args = {}
    later_args[:wait] = wait if wait && Rails.env.production?
    active_template(title)&.mail(**args)&.deliver_later(**later_args)
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
    ensure_liquid_data_previews
    mailer_preview.call(email_method,
      template: self,
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
    @liquid_data_previews&.dig(I18n.locale.to_s)
  end

  def to_param
    title
  end

  def display_name
    I18n.t("mail_template.title.#{title}")
  end

  def description
    I18n.t("mail_template.description.#{title}").html_safe
  end

  def with_delivery_cycles_scope?
    title.in?(TITLES_WITH_DELIVERY_CYCLES_SCOPE)
  end

  def scope_name
    if title.in?(BIDDING_ROUND_TITLES)
      "bidding_round"
    else
      title.split("_").first
    end
  end

  def scope_class
    scope_name.classify.constantize
  end

  def mailer
    "#{scope_name}_mailer".classify.constantize
  end

  def mailer_preview
    "#{scope_name}_mailer_preview".classify.constantize
  end

  def email_method
    "#{title.gsub(/^#{scope_name}_/, "")}_email"
  end

  def contents=(hash)
    super hash.transform_values { |v| v.strip + "\n" }
  end

  def always_active?
    title.in?(ALWAYS_ACTIVE_TITLES)
  end

  def active_by_default?
    title.in?(ACTIVE_BY_DEFAULT_TITLES)
  end

  def active=(value)
    if always_active?
      super(true)
    else
      super
    end
  end

  def inactive?
    case title
    when "invoice_overdue_notice"
      !Current.org.bank_connection?
    when "membership_renewal_reminder"
      Current.org.open_renewal_reminder_sent_after_in_days.blank?
    when "bidding_round_opened_reminder"
      Current.org.open_bidding_round_reminder_sent_after_in_days.blank?
    when "membership_second_last_trial_basket"
      Current.org.trial_baskets_count < 2
    when "absence_included_reminder"
      !Current.org.absences_included_reminder_enabled?
    else
      false
    end
  end

  def active
    inactive? ? false : super
  end

  def delivery_cycle_ids=(ids)
    all_ids = DeliveryCycle.order(:id).pluck(:id)
    ids = ids.map(&:presence).compact.map(&:to_i) & all_ids
    super (ids.sort == all_ids || ids.empty?) ? nil : ids
  end

  def delivery_cycle_ids
    super || DeliveryCycle.pluck(:id)
  end

  private

  def ensure_liquid_data_previews
    return if @liquid_data_previews

    self.liquid_data_preview_yamls = liquid_data_preview_yamls
  end

  def subjects_must_be_valid
    validate_liquid(:subjects)
  end

  def contents_must_be_valid
    validate_liquid(:contents)
    validate_html(:contents)
  end

  def set_defaults
    self.active = active_by_default? if new_record? && !active
    self.subjects = default_subjects
    self.contents = default_contents
  end

  def default_subjects
    Organization.languages.reduce({}) do |h, locale|
      h[locale] = subjects[locale] || I18n.with_locale(locale) {
        I18n.t("mail_template.default_subjects.#{title}")
      }
      h
    end
  end

  def default_contents
    Organization.languages.reduce({}) do |h, locale|
      path = Rails.root.join("app/views/mail_templates/#{title}.#{locale}.liquid")
      h[locale] = contents[locale] || File.read(path)
      h
    end
  end
end
