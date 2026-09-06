# frozen_string_literal: true

module Demo::Seeder::Mail
  extend ActiveSupport::Concern

  private

  def seed_newsletter!
    log "Seeding newsletter..."
    return if @active_members.blank?

    template = Newsletter::Template.first
    return unless template

    block_attributes = { "0" => { block_id: "text" } }
    Current.org.languages.each do |locale|
      block_attributes["0"]["content_#{locale}"] = translated_text("newsletter_content")[locale]
    end
    newsletter = Newsletter.create!(
      template: template,
      subjects: translated_text("News from the farm"),
      audience: "member_state::all",
      blocks_attributes: block_attributes)
    newsletter.send!
  end

  def seed_email_suppressions!
    log "Seeding email suppressions..."
    return if @active_members.size < 2

    members = @active_members.last(2)
    EmailSuppression.create!(
      email: members[0].emails_array.first,
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Recipient")
    EmailSuppression.create!(
      email: members[1].emails_array.first,
      stream_id: "outbound",
      reason: "HardBounce",
      origin: "Recipient")
  end

  def seed_mail_deliveries!
    log "Seeding mail deliveries..."
    return if @active_members.blank?

    %w[member_validated membership_renewal].each do |title|
      MailTemplate.find_by(title: title)&.update!(active: true)
    end
    members = @active_members.first(5)
    deliver_invoice_created_mails!
    deliver_member_validated_mails!(members)
    deliver_absence_created_mails!
    deliver_membership_renewal_mails!(members)
  end

  def deliver_invoice_created_mails!
    template = MailTemplate.find_by!(title: "invoice_created")
    Invoice.where.not(sent_at: nil).limit(3).each do |invoice|
      template.deliver!(invoice: invoice)
    end
  end

  def deliver_member_validated_mails!(members)
    template = MailTemplate.find_by!(title: "member_validated")
    members.first(3).each { |member| template.deliver!(member: member) }
  end

  def deliver_absence_created_mails!
    template = MailTemplate.find_by!(title: "absence_created")
    Absence.limit(2).each { |absence| template.deliver!(absence: absence) }
  end

  def deliver_membership_renewal_mails!(members)
    template = MailTemplate.find_by!(title: "membership_renewal")
    members.first(2).each do |member|
      next unless (membership = member.current_membership)

      template.deliver!(membership: membership)
    end
  end

  def seed_bidding_round_mail_deliveries!(members)
    return unless germany?
    return if members.blank?

    failed = BiddingRound.failed.order(:number).first
    completed = BiddingRound.completed.order(:number).first
    return unless failed && completed

    deliver_bidding_round_mails!("bidding_round_opened", completed, members)
    deliver_bidding_round_mails!("bidding_round_failed", failed, members)
    deliver_bidding_round_mails!("bidding_round_completed", completed, members)
  end

  def deliver_bidding_round_mails!(title, bidding_round, members)
    template = MailTemplate.find_by!(title: title)
    members.first(2).each do |member|
      next unless bidding_round.eligible?(member)

      template.deliver!(bidding_round: bidding_round, member: member)
    end
  end

  def mark_deliveries_delivered!
    MailDelivery::Email.find_each do |email|
      next unless email.processing?

      begin
        email.process!
        email.reload
      rescue ActiveStorage::FileNotFoundError
        # PDF not yet on S3; skip preview, just mark delivered below.
      end
      email.delivered!(at: 1.week.ago) if email.processing?
    end
  end
end
