# frozen_string_literal: true

class Notification::BasketSecondLastTrial < Notification::Base
  mail_template :basket_second_last_trial

  def notify
    return unless mail_template_active?

    eligible_baskets.each do |basket|
      deliver_later(basket: basket)
      basket.membership.touch(:second_last_trial_basket_sent_at)
    end
  end

  private

  def eligible_baskets
    Membership
      .trial
      .where(delivery_cycle_id: mail_template.delivery_cycle_ids)
      .where(second_last_trial_basket_sent_at: nil)
      .includes(:member, baskets: :delivery)
      .select(&:can_send_email?)
      .reject(&:trial_only?)
      .select { |m| m.baskets.trial.count >= 2 }
      .filter_map { |m| m.baskets.trial[-2] }
      .select { |b| b.delivery.date.today? }
  end
end
