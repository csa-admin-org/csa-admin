# frozen_string_literal: true

# Unified email delivery tracking for both newsletters and template emails.
#
# One MailDelivery per member per dispatch, with child MailDelivery::Email
# records tracking per-address delivery status.
#
# Polymorphic design:
#   mailable_type  — scope-derived model name ("Invoice", "Newsletter", etc.)
#   mailable_ids   — JSON array of record IDs (usually [single_id], groups for ActivityParticipation)
#   action         — the email action ("created", "reminder", "newsletter", etc.)
#
# Together, mailable_type + action identify the MailTemplate:
#   "#{mailable_type.underscore}_#{action}" → "invoice_created"
#
# State machine (MailDelivery level):
#   draft → processing → delivered / partially_delivered / not_delivered
#
#   - draft:               Newsletter draft — member is in audience, no Email children yet
#   - processing:          At least one Email child is still in processing state
#   - delivered:           All Email children reached delivered state
#   - partially_delivered: Mix of delivered and suppressed/bounced (at least one delivered)
#   - not_delivered:       All Email children are suppressed or bounced (none delivered)
#
# State is recomputed from Email children after any Email state transition.
#
# Delivery flow (both template and newsletter):
#   1. Caller invokes MailDelivery.deliver! (sync: creates tracking records)
#   2. Each Email's after_create_commit enqueues ProcessJob (async)
#   3. ProcessJob builds the Mail::Message, delivers, captures tracking data
#   4. ProcessJob calls recompute_state! after delivery
class MailDelivery < ApplicationRecord
  include HasState
  include Preview
  include Retention

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

  # Creates one MailDelivery per member with Email children per recipient.
  # All actual email sending happens asynchronously via ProcessJob.
  #
  # Arguments:
  #   member:        — the Member receiving the delivery
  #   mailable:      — an AR record, array of records, or nil (e.g. absence_included_reminder)
  #   mailable_type: — explicit type override (derived from mailable when present)
  #   action:        — the email action ("created", "newsletter", etc.)
  #   draft:         — true for newsletter drafts (no Email children)
  #   recipients:    — explicit email list; nil falls back to member.active_emails
  #
  # Returns the created MailDelivery record.
  #
  #   MailDelivery.deliver!(
  #     member: member,
  #     mailable: invoice,
  #     action: "created",
  #     recipients: ["a@b.com", "c@d.com"]
  #   )
  #
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
        # Email's after_create_commit enqueues ProcessJob automatically
        delivery.emails.create!(email: recipient, state: :processing)
      end

      delivery
    end
  end

  # Delegates to source.build_mail_for — both MailTemplate and Newsletter
  # implement the same interface, so no type-checking is needed.
  def build_message(email:)
    source.build_mail_for(member, email: email, **mailable_params)
  end

  # Recomputes state from Email children after any Email state transition.
  # Skipped for drafts (which have no Email children).
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
    newsletter? && source.scheduled? ? "scheduled" : super
  end

  def draft?
    state.in? %w[ draft scheduled ]
  end

  def mailables
    mailable_type.constantize.where(id: mailable_ids)
  end

  # Use preload_source! on collections to avoid N+1.
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

  # The MailTemplate title derived from mailable_type + action.
  # Used for source lookup and preloading.
  #
  # Most titles follow {scope}_{action} (e.g. "invoice" + "created" → "invoice_created").
  # One outlier — absence_included_reminder — lives in the "membership" scope but
  # doesn't start with "membership_". In that case the action stores the full title
  # and the reconstructed candidate won't match, so we fall back to the raw action.
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

  # Returns the email addresses the member should currently receive,
  # as determined by the source (Newsletter or MailTemplate).
  # Both sources implement recipients_for(member).
  def expected_member_emails
    source.recipients_for(member) || []
  end

  # Email addresses the member now has that were not included in this delivery.
  # Only meaningful for processed deliveries within the allowed period.
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

  # Delivers to a missing email address by adding a new Email child.
  # The Email's after_create_commit enqueues ProcessJob automatically.
  def deliver_missing_email!(email)
    raise "Email not missing" unless missing_emails.include?(email)

    emails.create!(email: email, state: :processing)
  end

  private

  # Returns the mailable context as kwargs for build_mail_for.
  # MailTemplate::Delivery passes these through to the mailer (e.g. invoice:, basket:).
  # Newsletter::Delivery accepts and ignores them via **.
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
