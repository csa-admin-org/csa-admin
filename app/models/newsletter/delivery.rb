class Newsletter
  class Delivery < ApplicationRecord
    self.table_name = "newsletter_deliveries"

    include HasState

    has_states :pending, :ignored, :delivered, :bounced

    belongs_to :newsletter
    belongs_to :member

    scope :with_email, -> { where.not(email: nil) }

    before_create :check_email_suppressions
    after_create_commit :enqueue_delivery_process_job

    def self.create_for!(newsletter, member)
      emails = member.emails_array
      # keep trace of the "delivery" even for members without email
      emails << nil if emails.empty?
      transaction do
        emails.each do |email|
          create!(
            newsletter: newsletter,
            member: member,
            email: email)
        end
      end
    end

    def self.find_by_email_and_tag(email, tag)
      newsletter_id = tag.to_s.split("-").last
      find_by(email: email, newsletter_id: newsletter_id)
    end

    def tag
      "newsletter-#{newsletter_id}"
    end

    def deliverable?
      email? && email_suppression_ids.empty?
    end

    def process!
      return if processed_at?

      attrs = {
        subject: email_render.subject,
        content: email_render.content,
        processed_at: Time.current
      }

      if deliverable?
        mailer.newsletter_email.deliver_later(queue: :low)
      else
        attrs[:state] = IGNORED_STATE
      end

      update!(attrs)
    end

    def delivered!(at:, **attrs)
      raise invalid_transition(:delivered) unless pending?

      update!({
        state: DELIVERED_STATE,
        delivered_at: at,
      }.merge(attrs))
    end

    def bounced!(at:, **attrs)
      raise invalid_transition(:bounced) unless pending?

      update!({
        state: BOUNCED_STATE,
        bounced_at: at,
      }.merge(attrs))
    end

    private

    def check_email_suppressions
      suppressions = EmailSuppression.active.where(email: email).select(:id, :reason)

      self.email_suppression_ids = suppressions.map(&:id)
      self.email_suppression_reasons = suppressions.map(&:reason).uniq
    end

    def enqueue_delivery_process_job
      DeliveryProcessJob.perform_later(self)
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
        signature: newsletter.signature.presence,
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
