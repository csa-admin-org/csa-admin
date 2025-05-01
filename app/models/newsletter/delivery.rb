# frozen_string_literal: true

class Newsletter
  class Delivery < ApplicationRecord
    self.table_name = "newsletter_deliveries"

    CONSIDER_STALE_AFTER = 12.hour

    include HasState

    has_states :draft, :processing, :ignored, :delivered, :bounced

    belongs_to :newsletter
    belongs_to :member

    scope :with_email, ->(email) { where("lower(email) LIKE ?", "%#{email.downcase}%") }
    scope :stale, -> { processing.where(created_at: ...CONSIDER_STALE_AFTER.ago) }
    scope :processed, -> { where.not(processed_at: nil) }

    before_create :check_email_suppressions
    after_create_commit :enqueue_delivery_process_job

    def self.create_for!(newsletter, member, draft: false, email: nil)
      state = draft ? :draft : :processing
      emails = email ? [ email ] : member.emails_array
      # keep trace of the "delivery" even for members without email
      emails << nil if emails.empty?
      transaction do
        emails.each do |email|
          create!(
            newsletter: newsletter,
            member: member,
            email: email,
            state: state)
        end
      end
    end

    def self.find_by_email_and_tag(email, tag)
      newsletter_id = tag.to_s.split("-").last
      find_by(email: email, newsletter_id: newsletter_id)
    end

    def self.ransackable_scopes(_auth_object = nil)
      %i[with_email]
    end

    def tag
      "newsletter-#{newsletter_id}"
    end

    def deliverable?
      email? && email_suppression_ids.empty?
    end

    def processed?
      processed_at?
    end

    def process!
      return if processed?

      attrs = {
        subject: email_render.subject,
        content: email_render.content,
        processed_at: Time.current
      }

      if deliverable?
        mailer.newsletter_email.deliver_later(queue: :low)
      end

      update!(attrs)
    end

    def ignored!
      update_columns(state: IGNORED_STATE)
    end

    def delivered!(at:, **attrs)
      raise invalid_transition(:delivered) unless processing?

      update!({
        state: DELIVERED_STATE,
        delivered_at: at
      }.merge(attrs))
    end

    def bounced!(at:, **attrs)
      raise invalid_transition(:bounced) unless processing?

      update!({
        state: BOUNCED_STATE,
        bounced_at: at
      }.merge(attrs))
    end

    def mail_preview
      mailer = NewsletterMailer.new
      mailer.send(:content_mail,
        # Fix image URLs, not sure why they are not resolved by ActionMailer with example.org
        content.gsub(%r{<img src=\"http://example.org}, "<img src=\"https://#{Current.org.members_url}"),
        subject: subject
      ).body
    end

    def subject
      processed? ? super : email_render.subject
    end

    def content
      processed? ? super : email_render.content
    end

    private

    def check_email_suppressions
      suppressions = EmailSuppression.active.where(email: email).select(:id, :reason)

      self.email_suppression_ids = suppressions.map(&:id)
      self.email_suppression_reasons = suppressions.map(&:reason).uniq
    end

    def enqueue_delivery_process_job
      DeliveryProcessJob.perform_later(self) unless draft?
      ignored! unless deliverable?
    end

    def mailer
      NewsletterMailer.with(mailer_params.merge(to: email))
    end

    def mailer_params
      {
        tag: tag,
        from: newsletter.from.presence,
        member: member,
        subject: newsletter.subject(member.language).to_s,
        template_contents: newsletter.template_contents,
        blocks: newsletter.relevant_blocks,
        signature: newsletter.signature_without_fallback(member.language),
        attachments: newsletter.attachments.to_a
      }
    end

    def email_render
      @email_render ||= begin
        mailer = NewsletterMailer.new
        mailer.params = mailer_params
        mailer.render_newsletter_email
      end
    end
  end
end
