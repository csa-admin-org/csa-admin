# frozen_string_literal: true

# Encapsulates delivery logic for Newsletter.
#
# Extracts the MailDelivery integration: querying deliveries, creating
# tracking records, and building the mailer message for ProcessJob.
#
# Shares the `build_mail_for(member, email:)` interface with
# MailTemplate::Delivery so MailDelivery can delegate uniformly.
class Newsletter
  module Delivery
    extend ActiveSupport::Concern

    class_methods do
      def deliveries_for(member)
        deliveries =
          MailDelivery
            .newsletters
            .processed
            .where(member: member)
            .order(created_at: :desc)
        newsletter_ids = deliveries.flat_map(&:mailable_ids).uniq
        newsletters = Newsletter.where(id: newsletter_ids).index_by(&:id)
        deliveries.each { |d| d.preload_source!(newsletters[d.mailable_ids.first]) }
        deliveries
      end
    end

    # Extra **kwargs match the shared build_mail_for interface.
    def build_mail_for(member, email:, **)
      NewsletterMailer.with(
        tag: tag,
        from: from.presence,
        member: member,
        subject: subject(member.language).to_s,
        template_contents: template_contents,
        blocks: relevant_blocks,
        signature: signature_without_fallback(member.language),
        attachments: attachments.to_a,
        to: email
      ).newsletter_email
    end

    def mail_deliveries
      MailDelivery.for_mailable(self)
    end

    def members
      Member.where(id: mail_deliveries.select(:member_id)).distinct
    end

    def mail_delivery_emails
      MailDelivery::Email
        .joins(:mail_delivery)
        .merge(MailDelivery.for_mailable(self))
    end

    def processing_delivery?
      mail_deliveries.processing.exists?
    end

    # Allow already-sent newsletter to be delivered to a new email address.
    # The member may already have a MailDelivery (from the original send),
    # so we find-or-create the parent and add a new Email child.
    def deliver!(email)
      return unless sent?
      return unless missing_delivery_emails.include?(email)

      member = Member.kept.find_by_email(email)
      delivery = mail_deliveries.find_by(member: member)

      if delivery
        delivery.emails.create!(email: email, state: :processing)
      else
        MailDelivery.deliver!(
          member: member,
          mailable: self,
          action: "newsletter",
          recipients: [ email ])
      end
    end

    def save_draft_deliveries!
      return if sent?

      create_deliveries!(draft: true)
    end

    def missing_delivery_emails
      audience_segment.emails - mail_delivery_emails.pluck(:email)
    end

    def missing_delivery_emails?
      missing_delivery_emails.any?
    end

    private

    def create_deliveries!(draft:)
      transaction do
        existing_ids = mail_deliveries.pluck(:id)
        MailDelivery::Email.where(mail_delivery_id: existing_ids).delete_all
        MailDelivery.where(id: existing_ids).delete_all
        audience_segment.members.each do |member|
          MailDelivery.deliver!(
            member: member,
            mailable: self,
            action: "newsletter",
            draft: draft)
        end
      end
    end
  end
end
