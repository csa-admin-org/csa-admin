# frozen_string_literal: true

module Support
  class InboundAddress
    DOMAIN = Support::Ticket::INBOUND_DOMAIN
    TOKEN = /\Aticket-([0-9a-f]{8})-(.+)\z/i
    CONVERT = /\Aticket-(.+)\z/i

    def self.parse(*addresses)
      parsed = emails_from(addresses).filter_map { |address|
        candidate = new(address)
        candidate if candidate.recognized?
      }
      parsed.find { |address| !address.convert? } || parsed.first
    end

    def self.emails_from(*addresses)
      addresses.flatten.compact.flat_map { |value|
        case value
        when Hash, ActionController::Parameters
          Array(value["Email"] || value[:Email] || value["email"])
        else
          value.to_s.scan(/[\w.+\-]+@[\w.\-]+/)
        end
      }
    end

    def self.from_email(payload)
      emails_from(
        payload["FromFull"],
        payload["From"],
        payload["MailboxHash"]).first
    end

    def self.operator_email?(email)
      return false if email.blank?

      operator_addresses.include?(canonical_local(email))
    end

    def self.operator_addresses
      [
        ENV["ULTRA_ADMIN_EMAIL"],
        ENV["SUPPORT_EMAIL"]
      ].compact.map { |address| canonical_local(address) }.uniq
    end

    def self.canonical_local(email)
      local, domain = email.to_s.downcase.split("@", 2)
      return email.to_s.downcase if domain.blank?

      "#{local.sub(/\+.*/, "")}@#{domain}"
    end

    def self.normalize_message_id(value)
      return if value.blank?

      id = value.to_s.strip
      id = "<#{id}>" unless id.start_with?("<")
      id
    end

    def self.message_id_from(payload)
      headers = Array(payload["Headers"])
      header = headers.find { |h|
        name = h["Name"] || h[:Name] || h["name"]
        name.to_s.casecmp("message-id").zero?
      }
      value = header && (header["Value"] || header[:Value] || header["value"])
      normalize_message_id(value.presence || payload["MessageID"])
    end

    attr_reader :token, :tenant, :convert

    def initialize(address)
      local, domain = split(address)
      return unless domain&.downcase == DOMAIN

      local = local.to_s.downcase
      if (match = local.match(TOKEN)) && Tenant.exists?(match[2])
        @token = match[1]
        @tenant = match[2]
      elsif (match = local.match(CONVERT)) && Tenant.exists?(match[1])
        @tenant = match[1]
        @convert = true
      end
    end

    def recognized?
      tenant.present?
    end

    def convert?
      convert == true
    end

    def demo?
      Tenant::DEMO_TENANT_PATTERN.match?(tenant.to_s)
    end

    private

    def split(address)
      return unless address.to_s.include?("@")

      local, domain = address.to_s.strip.split("@", 2)
      [ local, domain ]
    end
  end
end
