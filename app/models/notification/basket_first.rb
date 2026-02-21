# frozen_string_literal: true

class Notification::BasketFirst < Notification::Base
  mail_template :basket_first

  def notify
    return unless mail_template_active?

    eligible_baskets.each do |basket|
      deliver(basket: basket)
      basket.membership.touch(:first_basket_sent_at)
    end
  end

  private

  def eligible_baskets
    Membership
      .current
      .where(delivery_cycle_id: mail_template.delivery_cycle_ids)
      .where(first_basket_sent_at: nil)
      .includes(:member, baskets: :delivery)
      .select(&:can_send_email?)
      .filter_map { |m| m.baskets.deliverable.first }
      .select { |b| b.delivery.date.today? }
  end
end
