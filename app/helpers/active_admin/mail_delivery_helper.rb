# frozen_string_literal: true

module ActiveAdmin::MailDeliveryHelper
  def mail_delivery_email_stats(arbre, deliveries, path_params:, list_class: "counts")
    arbre.ul class: list_class do
      MailDelivery::Email::STATES.each do |email_state|
        arbre.li do
          count = deliveries.public_send(email_state).count
          label = t("active_admin.resources.mail_delivery.scopes.#{email_state}")
          link_to mail_deliveries_path(**path_params, scope: email_state) do
            counter_tag(label, count)
          end
        end
      end
    end
  end

  def missing_delivery_emails_grid(arbre, mailable)
    arbre.div(class: "mail-recipient-list") do
      mailable.deliveries_with_missing_emails.each do |delivery|
        delivery.missing_emails.each do |email|
          arbre.div(class: "mail-recipient is-start") do
            arbre.h4(class: "mail-recipient-title") { auto_link delivery, email }
            arbre.span(class: "text-sm is-muted") { "(#{auto_link(delivery.member)})".html_safe }
          end
        end
      end
    end
  end
end
