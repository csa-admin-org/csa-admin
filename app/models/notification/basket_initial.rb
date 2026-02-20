# frozen_string_literal: true

class Notification::BasketInitial < Notification::Base
  mail_template :basket_initial

  def notify
    return unless mail_template_active?

    eligible_baskets.each do |basket|
      member = basket.member
      next if already_sent?(member)
      next if basket.membership.previous_membership&.renewed?

      deliver_later(basket: basket)
      member.touch(:initial_basket_sent_at)
    end
  end

  private

  def eligible_baskets
    Membership
      .current
      .where(delivery_cycle_id: mail_template.delivery_cycle_ids)
      .includes(:member, baskets: :delivery)
      .select(&:can_send_email?)
      .filter_map { |m| m.baskets.deliverable.first }
      .select { |b| b.delivery.date.today? }
  end

  def already_sent?(member)
    member.initial_basket_sent_at? && member.initial_basket_sent_at >= member.activated_at
  end
end
