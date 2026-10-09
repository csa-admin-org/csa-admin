# frozen_string_literal: true

class MailDelivery < ApplicationRecord
  include HasState
  include Preview
  include Retention

  MAILABLE_TYPES = %w[Invoice Absence ActivityParticipation Membership BiddingRound Basket SEPAMandate Session].freeze
  MISSING_EMAILS_ALLOWED_PERIOD = 1.week

  has_states :draft, :processing, :delivered, :partially_delivered, :not_delivered

  belongs_to :member
  belongs_to :source_newsletter, class_name: "Newsletter",
    foreign_key: :mailable_id, optional: true
  has_many :emails, class_name: "MailDelivery::Email", dependent: :destroy

  scope :processed, -> { where.not(state: [ :draft, :processing ]) }
  scope :newsletters, -> { where(mailable_type: "Newsletter") }
  scope :mail_templates, -> { where.not(mailable_type: "Newsletter") }
  scope :without_content, -> { select(*(column_names - [ "content" ])) }
  scope :with_email, ->(email) {
    joins(:emails).merge(Email.with_email(email))
  }
  scope :with_subject, ->(subject) {
    processed.where("subject LIKE ?", "%#{subject}%")
  }
  scope :newsletter_id_eq, ->(id) { where(mailable_type: "Newsletter", mailable_id: id) }
  scope :mail_template_id_eq, ->(id) {
    template = MailTemplate.find(id)
    where(
      mailable_type: template.scope_name.classify,
      action: template.action)
  }
  scope :for_mailable, ->(record) {
    relation = where(mailable_type: record.class.name)
    if record.is_a?(ActivityParticipation)
      relation.where("EXISTS (SELECT 1 FROM json_each(mailable_ids) WHERE value = ?)", record.id)
    else
      relation.where(mailable_id: record.id)
    end
  }
  MailDelivery::Email::STATES.each do |email_state|
    scope email_state, -> { joins(:emails).where(emails: { state: email_state }).distinct }
  end

  def self.email_state_counts
    counts = joins(:emails).group("emails.state").count("DISTINCT mail_deliveries.id")
    Email::STATES.index_with { |state| counts[state] || 0 }
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

  # Bulk counterpart to deliver! for a whole audience. insert_all skips
  # Email callbacks, so suppressions are applied here and ProcessJob is
  # enqueued with perform_all_later.
  def self.deliver_all!(members:, mailable:, action:, draft: false)
    members = Array(members)
    mailables = Array(mailable).compact
    return if members.empty?

    addresses = members.flat_map(&:emails_array).uniq
    outbound_suppressed = EmailSuppression.outbound.active
      .where(email: addresses).pluck(:email).to_set
    suppression_scope = EmailSuppression.active.where(email: addresses)
    suppression_scope = suppression_scope.outbound unless mailables.first.is_a?(Newsletter)
    suppressions_by_email = suppression_scope.select(:id, :email, :reason).group_by(&:email)
    recipients_by_member_id = members.to_h { |member|
      next [ member.id, [] ] if member.discarded?

      [ member.id, member.emails_array.reject { |email| outbound_suppressed.include?(email) } ]
    }
    now = Time.current

    transaction do
      insert_all!(members.map { |member|
        recipients = recipients_by_member_id[member.id]
        {
          mailable_type: mailables.first.class.name,
          mailable_ids: mailables.map(&:id),
          action: action,
          member_id: member.id,
          state: draft ? "draft" : (recipients.any? ? "processing" : "not_delivered"),
          created_at: now,
          updated_at: now
        }
      })

      next if draft

      deliveries = for_mailable(mailable).where(member_id: members.map(&:id)).to_a
      email_rows = deliveries.flat_map { |delivery|
        recipients_by_member_id[delivery.member_id].map { |email|
          suppressions = suppressions_by_email[email] || []
          {
            mail_delivery_id: delivery.id,
            email: email,
            state: "processing",
            email_suppression_ids: suppressions.map(&:id),
            email_suppression_reasons: suppressions.map(&:reason).uniq,
            created_at: now,
            updated_at: now
          }
        }
      }
      Email.insert_all!(email_rows) if email_rows.any?
    end

    return if draft

    emails = Email.where(mail_delivery_id: for_mailable(mailable).select(:id))
    ActiveJob.perform_all_later(emails.map { |email| ProcessJob.new(email) })
  end

  def build_message(email:)
    source.build_mail_for(member, email: email, **mailable_params)
  end

  def display_name
    if session?
      I18n.t("session_mailer.#{session_mailer_method}.subject")
    else
      source&.display_name
    end
  end

  def mailable_missing?
    mailable_ids.present? && mailables.none?
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
      source_newsletter
    elsif session?
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
    return if newsletter? || session?
    return "price_reduction_card_expiring" if mailable_type == "MemberCard"

    candidate = "#{mailable_type.underscore}_#{action}"
    candidate.in?(MailTemplate::TITLES) ? candidate : action
  end

  def newsletter?
    mailable_type == "Newsletter"
  end

  def session?
    mailable_type == "Session"
  end

  def newsletter
    source if newsletter?
  end

  def expected_member_emails
    source.recipients_for(member) || []
  end

  def missing_emails
    return [] if draft?

    expected_member_emails - emails.map(&:email)
  end

  def missing_emails_allowed?
    !draft? && created_at > MISSING_EMAILS_ALLOWED_PERIOD.ago
  end

  def show_missing_emails?
    !session? && missing_emails_allowed? && missing_emails.any?
  end

  def deliver_missing_email!(email)
    raise "Email not missing" unless missing_emails.include?(email)

    emails.create!(email: email, state: :processing)
  end

  private

  def session_mailer_method
    case action
    when "created" then "new_member_session_email"
    when "deletion_confirmation" then "deletion_confirmation_email"
    end
  end

  def mailable_params
    return {} if mailable_ids.blank?

    records = mailables.to_a
    return {} if records.empty?

    key = mailable_type.underscore.to_sym
    params = if records.size == 1 && mailable_ids.size == 1
      { key => records.first }
    else
      # For ActivityParticipation groups: pass IDs array
      { "#{key}_ids": mailable_ids }
    end
    params[:action] = action if session?
    params
  end
end
