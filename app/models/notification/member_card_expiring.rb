# frozen_string_literal: true

class Notification::MemberCardExpiring < Notification::Base
  mail_template :price_reduction_card_expiring

  def notify
    return unless Current.org.feature?("price_reductions")

    cards = due_cards
    return if cards.empty?

    cards.each do |card|
      deliver(member: card.member, member_card: card) if mail_template_active?
      card.update_columns(expiration_notice_sent_on: card.expires_on)
    end

    relevant = cards.select { |card| admin_relevant?(card) }
    Admin.notify!(:member_card_expiring, member_cards: relevant) if relevant.any?
  end

  private

  def due_cards
    remind_before_days = MailTemplate.card_expiring_remind_before_days
    MemberCard
      .includes(:member, :price_reduction_card)
      .select { |card| card.notice_due?(remind_before_days: remind_before_days) }
  end

  def admin_relevant?(card)
    type_id = card.price_reduction_card_id
    return true if card.member.waiting_price_reduction&.price_reduction_card_id == type_id

    MembershipPriceReduction
      .joins(:membership, :price_reduction)
      .merge(Membership.current_or_future.where(member_id: card.member_id))
      .where(price_reductions: { price_reduction_card_id: type_id })
      .exists?
  end
end
