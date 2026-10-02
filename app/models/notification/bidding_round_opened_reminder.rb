# frozen_string_literal: true

class Notification::BiddingRoundOpenedReminder < Notification::Base
  mail_template :bidding_round_opened_reminder

  def notify
    return unless Current.org.feature?("bidding_round")
    return unless mail_template_active?
    return unless bidding_round
    return if reminder_delay.future?

    eligible_memberships.find_each do |membership|
      deliver(bidding_round: bidding_round, member: membership.member)
      membership.touch(:bidding_round_opened_reminder_sent_at)
    end
  end

  private

  def reminder_delay_in_days
    MailTemplate.delay_in_days_for("bidding_round_opened_reminder")
  end

  def bidding_round
    @bidding_round ||= BiddingRound.current_open
  end

  def reminder_delay
    bidding_round.created_at + reminder_delay_in_days.days
  end

  def eligible_memberships
    bidding_round
      .eligible_memberships
      .where.not(id: bidding_round.pledges.select(:membership_id))
      .merge(
        Membership.where(bidding_round_opened_reminder_sent_at: ..reminder_delay)
          .or(Membership.where(bidding_round_opened_reminder_sent_at: nil))
      )
  end
end
