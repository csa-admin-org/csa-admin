# frozen_string_literal: true

class MailDelivery < ApplicationRecord
  include HasState
  include Preview
  include Retention

  MAILABLE_TYPES = %w[Invoice Absence ActivityParticipation Membership BiddingRound Basket].freeze
  MISSING_EMAILS_ALLOWED_PERIOD = 1.week

  has_states :draft, :processing, :delivered, :partially_delivered, :not_delivered

  belongs_to :member
  has_many :emails, class_name: "MailDelivery::Email", dependent: :destroy

  scope :processed, -> { where.not(state: [ :draft, :processing ]) }
  scope :newsletters, -> { where(mailable_type: "Newsletter") }
  scope :mail_templates, -> { where.not(mailable_type: "Newsletter") }
  scope :with_email, ->(email) {
    joins(:emails).merge(Email.with_email(email))
  }
  scope :with_subject, ->(subject) {
    processed.where("subject LIKE ?", "%#{subject}%")
  }
  scope :newsletter_id_eq, ->(id) { for_mailable(Newsletter.find(id)) }
  scope :mail_template_id_eq, ->(id) {
    template = MailTemplate.find(id)
    where(
      mailable_type: template.scope_name.classify,
      action: template.action)
  }
  scope :for_mailable, ->(record) {
    where(mailable_type: record.class.name)
      .where("EXISTS (SELECT 1 FROM json_each(mailable_ids) WHERE value = ?)", record.id)
  }
  MailDelivery::Email::STATES.each do |email_state|
    scope email_state, -> { joins(:emails).where(emails: { state: email_state }).distinct }
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[newsletter_id_eq mail_template_id_eq with_email with_subject]
  end

  def self.deliver!(member:, mailable: nil, mailable_type: nil, action:, draft: false, recipients: nil)
    mailables = Array(mailable).compact
    mailable_type ||= mailables.first&.class&.name
    recipients = nil if draft
    recipients ||= member.active_emails.presence unless draft

    state = if draft then :draft
    elsif recipients then :processing
    else :not_delivered
    end

    transaction do
      delivery = create!(
        mailable_type: mailable_type,
        mailable_ids: mailables.map(&:id),
        action: action,
        member: member,
        state: state)

      Array(recipients).each do |recipient|
        # after_create_commit enqueues ProcessJob automatically
        delivery.emails.create!(email: recipient, state: :processing)
      end

      delivery
    end
  end

  def build_message(email:)
    source.build_mail_for(member, email: email, **mailable_params)
  end

  def recompute_state!
    return if draft?

    loaded_emails = emails.reload

    new_state = if loaded_emails.empty? || loaded_emails.all?(&:suppressed?)
      :not_delivered
    elsif loaded_emails.any?(&:processing?)
      :processing
    elsif loaded_emails.all?(&:delivered?)
      :delivered
    elsif loaded_emails.any?(&:delivered?)
      :partially_delivered
    else
      :not_delivered
    end

    update_column(:state, new_state) unless state == new_state
  end

  def state
    newsletter? && source&.scheduled? ? "scheduled" : super
  end

  def draft?
    state.in? %w[ draft scheduled ]
  end

  def mailables
    mailable_type.constantize.where(id: mailable_ids)
  end

  def source
    @source ||= if newsletter?
      mailables.first
    else
      MailTemplate.find_by!(title: mail_template_title)
    end
  end

  def preload_source!(record)
    @source = record
  end

  # absence_included_reminder lives in the "membership" scope but doesn't start
  # with "membership_", so the candidate won't match — fall back to raw action.
  def mail_template_title
    return if newsletter?

    candidate = "#{mailable_type.underscore}_#{action}"
    candidate.in?(MailTemplate::TITLES) ? candidate : action
  end

  def newsletter?
    mailable_type == "Newsletter"
  end

  def newsletter
    source if newsletter?
  end

  def expected_member_emails
    source.recipients_for(member) || []
  end

  def missing_emails
    return [] if draft?

    expected_member_emails - emails.pluck(:email)
  end

  def missing_emails_allowed?
    !draft? && created_at > MISSING_EMAILS_ALLOWED_PERIOD.ago
  end

  def show_missing_emails?
    missing_emails_allowed? && missing_emails.any?
  end

  def deliver_missing_email!(email)
    raise "Email not missing" unless missing_emails.include?(email)

    emails.create!(email: email, state: :processing)
  end

  private

  def mailable_params
    return {} if mailable_ids.blank?

    records = mailables.to_a
    key = mailable_type.underscore.to_sym

    if records.size == 1
      { key => records.first }
    else
      # For ActivityParticipation groups: pass IDs array
      { "#{key}_ids": mailable_ids }
    end
  end
end
