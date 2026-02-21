# frozen_string_literal: true

# Encapsulates delivery logic for MailTemplate.
#
# Extracts the MailDelivery integration: how to create tracking records,
# resolve the member/mailable from caller args, and build the mailer
# message for ProcessJob.
#
# Shares the `build_mail_for(member, email:)` interface with
# Newsletter::Delivery so MailDelivery can delegate uniformly.
class MailTemplate
  module Delivery
    extend ActiveSupport::Concern

    class_methods do
      def deliver(title, **args)
        active_template(title)&.deliver!(**args)
      end
    end

    # Creates tracking records synchronously, then delivers each email
    # asynchronously via ProcessJob.
    #
    # Record creation is always sync (tracking exists immediately),
    # actual sending is always async via ProcessJob.
    def deliver!(**args)
      member = member(**args)
      return unless member

      MailDelivery.deliver!(
        member: member,
        mailable: mailable(**args),
        action: action,
        recipients: recipients_for(member))
    end

    # **args carry the mailable context (e.g. invoice:, basket:)
    # reconstructed by MailDelivery#mailable_params.
    def build_mail_for(member, email:, **args)
      mail(to: email, member: member, **args)
    end

    # Extracts the mailable record(s) from the args passed to deliver.
    # Convention: callers pass a kwarg matching scope_name (e.g. invoice:,
    # basket:, membership:). The one exception is activity_participation_ids
    # for grouped participations, which requires a DB lookup.
    def mailable(**args)
      if (ids = args[:"#{scope_name}_ids"])
        scope_class.where(id: ids).to_a
      else
        args[scope_name.to_sym]
      end
    end

    # Extracts the member from the args passed to deliver.
    # Uses explicit member: when present (e.g. bidding_round notifications),
    # otherwise derives from the mailable's associations.
    def member(**args)
      return args[:member] if args[:member]

      mailable = Array(mailable(**args)).first
      return mailable if mailable.is_a?(Member)

      mailable&.try(:member) || mailable&.try(:membership)&.member
    end

    # Returns the recipient email addresses for the given member.
    # Invoice templates use billing_emails; all others use active_emails.
    # Returns nil for members with no email (deliver! creates a not_delivered trace).
    def recipients_for(member)
      emails = title.in?(INVOICE_TITLES) ? member.billing_emails : member.active_emails
      emails.presence
    end

    def mail_deliveries
      MailDelivery.where(mailable_type: scope_name.classify, action: action)
    end

    # Returns recent MailDelivery records where the member now has
    # email addresses that were not included in the original delivery.
    # Used by the admin UI to link to individual deliveries.
    def deliveries_with_missing_emails
      recent = mail_deliveries
        .where.not(state: :draft)
        .where("created_at > ?", MailDelivery::MISSING_EMAILS_ALLOWED_PERIOD.ago)
        .includes(:member, :emails)
        .to_a
      recent.each { |d| d.preload_source!(self) }
      recent.select { |d| d.missing_emails.any? }
    end

    def show_missing_delivery_emails?
      deliveries_with_missing_emails.any?
    end
  end
end
