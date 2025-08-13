# frozen_string_literal: true

namespace :postmark do
  desc "Setup/check Postmark server and display configuration"
  task server: :environment do
    account_token = Rails.application.credentials.postmark_account_token
    raise "Missing postmark_account_token in credentials" unless account_token

    client = Postmark::AccountApiClient.new(account_token)

    Tenant.switch_each do
      next if Tenant.custom? && !ENV["TENANT"]

      puts "\n#{Current.org.name} (#{Tenant.current})"

      if Current.org.postmark_server_id?
        # Display existing configuration
        server = client.get_server(Current.org.postmark_server_id)
        puts "  Server ID: #{server[:id]}"
        puts "  Server Name: #{server[:name]}"
        puts "  Server Token: #{Current.org.postmark_server_token[0..10]}..."
        puts "  ✅ Server configured"
      else
        # Create new server
        print "  Creating new Postmark server..."

        server = client.create_server(
          name: Current.org.name,
          color: "green",
          smtp_api_activated: false,
          raw_email_enabled: false,
          delivery_type: "Live",
          post_first_open_only: false,
          track_opens: false,
          track_links: "None",
          include_bounce_content_in_hook: false,
          enable_smtp_api_error_hooks: false)

        Current.org.update!(
          postmark_server_id: server[:id],
          postmark_server_token: server[:api_tokens].first)

        puts " done!"
        puts "  Server ID: #{server[:id]}"
        puts "  Server Name: #{server[:name]}"
        puts "  Server Token: #{server_tokens[:api_tokens].first[0..10]}..."
        puts "  ✅ Server created and configured"
      end
    end
  end

  desc "Setup/verify Postmark domain and DNS configuration"
  task domain: :environment do
    account_token = Rails.application.credentials.postmark_account_token
    raise "Missing postmark_account_token in credentials" unless account_token

    client = Postmark::AccountApiClient.new(account_token)

    Tenant.switch_each do
      next if Tenant.custom? && !ENV["TENANT"]
      next unless Current.org.postmark_server_id.present?

      puts "\n#{Current.org.name} (#{Tenant.current})"
      puts "  Domain: #{Current.org.domain}"

      # Get all domains for this server
      domains = client.get_domains(count: 500)
      domain = domains.find { |d| d[:name] == Current.org.domain }

      if domain
        # Verify existing domain
        domain_details = client.get_domain(domain[:id])

        puts "  Domain ID: #{domain[:id]}"
        puts "  Status:"
        puts "    DKIM: #{domain_details[:dkim_verified] ? '✅' : '❌'}"
        puts "    Return-Path: #{domain_details[:return_path_domain_verified] ? '✅' : '❌'}"

        unless domain_details[:dkim_verified] && domain_details[:return_path_domain_verified]
          puts "\n  Required DNS Records:"

          unless domain_details[:dkim_verified]
            puts "\n  DKIM Record:"
            puts "    Type: TXT"
            puts "    Host: #{domain_details[:dkim_host]}"
            puts "    Value: #{domain_details[:dkim_text_value]}"
          end

          unless domain_details[:return_path_domain_verified]
            puts "\n  Return-Path Record:"
            puts "    Type: CNAME"
            puts "    Host: #{domain_details[:return_path_domain]}"
            puts "    Value: #{domain_details[:return_path_domain_cname_value]}"
          end

          # Try to verify the domain
          print "\n  Verifying domain..."
          begin
            client.verify_domain_dkim(domain[:id])
            client.verify_domain_return_path(domain[:id])
            puts " done!"
          rescue
            puts " verification pending"
          end
        else
          puts "  ✅ Domain fully verified"
        end
      else
        # Create new domain
        print "  Creating new domain..."

        new_domain = client.create_domain(name: Current.org.domain)

        puts " done!"
        puts "  Domain ID: #{new_domain[:id]}"

        # Display DNS records to configure
        puts "\n  Required DNS Records:"

        puts "\n  DKIM Record:"
        puts "    Type: TXT"
        puts "    Host: #{new_domain[:dkim_host]}"
        puts "    Value: #{new_domain[:dkim_text_value]}"

        puts "\n  Return-Path Record:"
        puts "    Type: CNAME"
        puts "    Host: #{new_domain[:return_path_domain]}"
        puts "    Value: #{new_domain[:return_path_domain_cname_value]}"
      end
    end
  end

  desc "Complete Postmark setup (server, domain, message streams, webhook)"
  task setup: :environment do
    Rake::Task["postmark:server"].invoke
    Rake::Task["postmark:domain"].invoke
    Rake::Task["postmark:message_streams"].invoke
    Rake::Task["postmark:webhook"].invoke
  end

  desc "Create/update message streams"
  task message_streams: :environment do
    Tenant.switch_each do
      next if Tenant.custom? && !ENV["TENANT"]

      if server_token = Current.org.postmark_server_token
        client = Postmark::ApiClient.new(server_token)

        outbound = client.get_message_stream("outbound")
        unless outbound[:name] == "Transactional Stream"
          client.update_message_stream("outbound", name: "Transactional Stream")
          puts "#{Current.org.name} - Outbound Stream updated"
        end

        inbound = client.get_message_stream("inbound")
        unless inbound[:name] == "Inbound Stream"
          client.update_message_stream("inbound", name: "Inbound Stream")
          puts "#{Current.org.name} - Inbound Stream updated"
        end

        broadcast = client.get_message_stream("broadcast")
        unless broadcast[:name] == "Broadcasts Stream"
          client.update_message_stream("broadcast", name: "Broadcasts Stream")
          puts "#{Current.org.name} - Broadcast Stream updated"
        end
        unless broadcast.dig(:subscription_management_configuration, "UnsubscribeHandlingType") == "Custom"
          client.update_message_stream("broadcast",
            subscription_management_configuration: { UnsubscribeHandlingType: "Custom" })
          puts "#{Current.org.name} - Broadcast Stream subscription management updated"
        end
      end
    end
  end

  desc "Create/update postmark webhook"
  task webhook: :environment do
    raise "Only run this rake task in production env" unless Rails.env.production?

    Tenant.switch_each do
      next if Tenant.custom? && !ENV["TENANT"]

      if server_token = Current.org.postmark_server_token
        client = Postmark::ApiClient.new(server_token)

        attrs = {
          url: Postmark.webhook_url,
          message_stream: "broadcast",
          http_headers: [
            {
              name: "Authorization",
              value: ActionController::HttpAuthentication::Token.encode_credentials(Postmark.webhook_token)
            }
          ],
          triggers: {
            delivery: { enabled: true },
            bounce: { enabled: true, include_content: false }
          }
        }

        webhooks = client.get_webhooks
        if webhook = webhooks.find { |wh| wh[:message_stream] == "broadcast" }
          client.update_webhook(webhook[:id], attrs)
          puts "#{Current.org.name} - Webhook updated"
        else
          client.create_webhook(attrs)
          puts "#{Current.org.name} - Webhook created"
        end
      end
    end
  end

  desc "Sync newsletter deliveries status"
  task sync_newsletter_deliveries: :environment do
    Tenant.switch_each do
      next if Tenant.custom? && !ENV["TENANT"]

      if server_token = Current.org.postmark_server_token
        client = Postmark::ApiClient.new(server_token)
        puts "Syncing newsletter deliveries for #{Current.org.name}"

        Newsletter.where(sent_at: 2.weeks.ago..).each do |newsletter|
          messages = client.get_messages(
            count: 500,
            tag: newsletter.tag,
            messagestream: "broadcast")
          puts "#{newsletter.tag} - #{messages.size} messages found"

          messages.each do |message|
            email = message[:recipients].first
            delivery = newsletter.deliveries.find_by(email: email)

            if delivery
              if delivery.postmark_message_id.nil?
                details = client.get_message(message[:message_id])

                if details[:status] == "Sent"
                  if event = details[:message_events].find { |e| e["Type"] == "Delivered" && e["Recipient"] == email }
                    delivery.transaction do
                      delivery.delivered!(
                        at: event["ReceivedAt"],
                        postmark_message_id: message[:message_id],
                        postmark_details: details.dig("Details", "DeliveryMessage")
                      )
                    end
                    puts "#{newsletter.tag} - delivered - #{delivery.id}"
                  elsif event = details[:message_events].find { |e| e["Type"] == "Bounced" && e["Recipient"] == email }
                    bounce_id = event.dig("Details", "BounceID")
                    bounce = client.get_bounce(bounce_id)

                    delivery.transaction do
                      delivery.bounced!(
                        at: bounce[:bounced_at],
                        postmark_message_id: bounce[:message_id],
                        postmark_details: bounce[:details],
                        bounce_type: bounce[:type],
                        bounce_type_code: bounce[:type_code],
                        bounce_description: bounce[:description])
                    end
                    puts "#{newsletter.tag} - bounced - #{delivery.id}"
                  end
                end
              end
            else
              puts "#{newsletter.tag} - delivery not found for #{email}"
            end
          end
        end
      end
    end
  end
end
