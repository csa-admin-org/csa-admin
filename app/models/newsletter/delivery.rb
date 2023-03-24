class Newsletter
  class Delivery < ApplicationRecord
    self.table_name = 'newsletter_deliveries'

    belongs_to :newsletter
    belongs_to :member

    scope :delivered, -> { where.not(delivered_at: nil) }
    scope :undelivered, -> { where(delivered_at: nil) }

    before_create :store_emails

    def delivered?
      delivered_at?
    end

    def deliver!
      raise 'Already delivered!' if delivered?

      transaction do
        emails.each { |email|
          mailer(email).newsletter_email.deliver_later(queue: :low)
        }
        update!(
          delivered_at: Time.current,
          subject: email_render.subject,
          content: email_render.content)
      end
    end

    private

    def store_emails
      self.suppressed_emails =
        EmailSuppression.broadcast.active.where(email: member.emails_array).pluck(:email).uniq
      self.emails = member.emails_array - suppressed_emails
    end

    def mailer(email)
      NewsletterMailer.with(mailer_params.merge(to: email))
    end

    def mailer_params
      {
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
