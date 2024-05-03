class Newsletter
  class Delivery < ApplicationRecord
    self.table_name = "newsletter_deliveries"

    belongs_to :newsletter
    belongs_to :member

    scope :deliverable, -> {
      where.not(email: nil).where(email_suppression_ids: [])
    }
    scope :suppressed, -> { where.not(email_suppression_ids: []) }
    scope :processed, -> { where.not(delivered_at: nil) } # TODO: rename to processed_at
    scope :unprocessed, -> { where(delivered_at: nil) } # TODO: rename to processed_at

    before_create :check_email_suppressions
    after_create_commit :enqueue_delivery_process_job

    def self.create_for!(newsletter, member)
      emails = member.emails_array
      # keep trace of the "delivery" even for members without email
      emails << nil if emails.empty?
      emails.each do |email|
        create!(
          newsletter: newsletter,
          member: member,
          email: email)
      end
    end

    def processed?
      delivered_at? # TODO: rename to processed_at
    end

    def deliverable?
      email? && email_suppression_ids.empty?
    end

    def process!
      raise "Already processed!" if processed?

      transaction do
        if deliverable?
          mailer.newsletter_email.deliver_later(queue: :low)
        end
        update!(
          delivered_at: Time.current, # TODO: rename to processed_at
          subject: email_render.subject,
          content: email_render.content)
      end
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
        newsletter_id: newsletter_id,
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
