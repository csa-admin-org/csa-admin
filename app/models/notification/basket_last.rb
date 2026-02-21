# frozen_string_literal: true

class Notification::BasketLast < Notification::Base
  mail_template :basket_last

  def notify
    return unless mail_template_active?

    eligible_baskets.each do |basket|
      deliver(basket: basket)
      basket.membership.touch(:last_basket_sent_at)
    end
  end

  private

  def eligible_baskets
    Membership
      .current
      .renewed
      .where(delivery_cycle_id: mail_template.delivery_cycle_ids)
      .where(last_basket_sent_at: nil)
      .includes(:member, baskets: :delivery)
      .select(&:can_send_email?)
      .filter_map { |m| m.baskets.deliverable.last }
      .select { |b| b.delivery.date.today? }
  end
end
