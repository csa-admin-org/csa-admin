# frozen_string_literal: true

namespace :postmark do
  desc "Create/update message streams"
  task message_streams_setup: :environment do
    Organization.switch_each do |org|
      if api_token = org.credentials(:postmark, :api_token)
        client = Postmark::ApiClient.new(api_token)

        outbound = client.get_message_stream("outbound")
        unless outbound[:name] == "Transactional Stream"
          client.update_message_stream("outbound", name: "Transactional Stream")
        end

        inbound = client.get_message_stream("inbound")
        unless inbound[:name] == "Inbound Stream"
          client.update_message_stream("inbound", name: "Inbound Stream")
        end

        brodcast = client.get_message_stream("broadcast")
        unless brodcast[:name] == "Broadcasts Stream"
          client.update_message_stream("broadcast", name: "Broadcasts Stream")
        end
        unless brodcast.dig(:subscription_management_configuration, "UnsubscribeHandlingType") == "Custom"
          client.update_message_stream("broadcast",
            subscription_management_configuration: { UnsubscribeHandlingType: "Custom" })
        end
      end
    end
  end

  desc "Create/update postmark webhook"
  task webhook_setup: :environment do
    Organization.switch_each do |org|
      if api_token = org.credentials(:postmark, :api_token)
        client = Postmark::ApiClient.new(api_token)

        attrs = {
          url: Postmark.webhook_url,
          message_stream: "broadcast",
          http_headers: [
            name: "Authorization",
            value: ActionController::HttpAuthentication::Token.encode_credentials(Postmark.webhook_token)
          ],
          triggers: {
            delivery: { enabled: true },
            bounce: { enabled: true, include_content: false }
          }
        }

        webhooks = client.get_webhooks
        if webhook = webhooks.find { |wh| wh[:message_stream] == "broadcast" }
          client.update_webhook(webhook[:id], attrs)
          puts "#{org.name} - Webhook updated"
        else
          client.create_webhook(attrs)
          puts "#{org.name} - Webhook created"
        end
      end
    end
  end

  desc "Sync newsletter deliveries status"
  task sync_newsletter_deliveries: :environment do
    Organization.switch_each do |org|
      if api_token = org.credentials(:postmark, :api_token)
        client = Postmark::ApiClient.new(api_token)
        pp "Syncing newsletter deliveries for #{org.name}"

        Newsletter.where(sent_at: 2.weeks.ago..).each do |newsletter|
          messages = client.get_messages(
            count: 500,
            tag: newsletter.tag,
            messagestream: "broadcast")
          pp "#{newsletter.tag} - #{messages.size} messages found"
          messages.each do |message|
            email = message[:recipients].first
            delivery = newsletter.deliveries.find_by(email: email)
            if delivery
              if delivery.postmark_message_id.nil?
                details = client.get_message(message[:message_id])
                if details[:status] == "Sent"
                  if event = details[:message_events].find { |e| e["Type"] == "Delivered" && e["Recipient"] == email }
                    delivery.transaction do
                      delivery.update_column(:state, "pending")
                      delivery.delivered!(
                        at: event["ReceivedAt"],
                        postmark_message_id: message[:message_id],
                        postmark_details: details.dig("Details", "DeliveryMessage"))
                    end
                    pp "#{newsletter.tag} - delivered - #{delivery.id}"
                  elsif event = details[:message_events].find { |e| e["Type"] == "Bounced" && e["Recipient"] == email }
                    bounce_id = event.dig("Details", "BounceID")
                    bounce = client.get_bounce(bounce_id)
                    delivery.transaction do
                      delivery.update_column(:state, "pending")
                      delivery.bounced!(
                        at: bounce[:bounced_at],
                        postmark_message_id: bounce[:message_id],
                        postmark_details: bounce[:details],
                        bounce_type: bounce[:type],
                        bounce_type_code: bounce[:type_code],
                        bounce_description: bounce[:description])
                    end
                    pp "#{newsletter.tag} - bounced - #{delivery.id}"
                  end
                end
              end
            else
              pp "#{newsletter.tag} - delivery not found for #{email}"
            end
          end
        end
      end
    end
  end
end
