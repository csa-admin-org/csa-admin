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
    arbre.div(class: "grid gap-y-2 mb-2") do
      mailable.deliveries_with_missing_emails.each do |delivery|
        delivery.missing_emails.each do |email|
          arbre.div(class: "flex flex-wrap items-center justify-start mx-2 gap-2") do
            arbre.h4(class: "m-0 text-lg font-extralight") { auto_link delivery, email }
            arbre.span(class: "text-sm text-gray-500") { "(#{auto_link(delivery.member)})".html_safe }
          end
        end
      end
    end
  end
end
