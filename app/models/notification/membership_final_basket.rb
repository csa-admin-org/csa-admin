# frozen_string_literal: true

class Notification::MembershipFinalBasket < Notification::Base
  mail_template :membership_final_basket

  def notify
    return unless mail_template_active?

    eligible_baskets.each do |basket|
      next if already_sent?(basket.member)

      deliver_later(basket: basket)
      basket.member.touch(:final_basket_sent_at)
    end
  end

  private

  def eligible_baskets
    Membership
      .current
      .where(delivery_cycle_id: mail_template.delivery_cycle_ids)
      .renewal_state_eq(:renewal_canceled)
      .includes(:member, baskets: :delivery)
      .select(&:can_send_email?)
      .filter_map { |m| m.baskets.deliverable.last }
      .select { |b| b.delivery.date.today? }
  end

  def already_sent?(member)
    member.final_basket_sent_at? && member.final_basket_sent_at >= member.activated_at
  end
end
