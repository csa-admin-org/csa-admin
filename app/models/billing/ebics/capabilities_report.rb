# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    class CapabilitiesReport
      ADMIN_ORDER_TYPES = %w[HTD HAA].freeze

      def initialize(tenant:, organization: Current.org, connection: organization.active_bank_connection, btf_client: nil)
        @tenant = tenant
        @organization = organization
        @connection = connection
        @btf_client = btf_client
      end

      def to_h
        {
          "tenant" => tenant,
          "organization" => organization.name,
          "country_code" => organization.country_code,
          "active_connection" => active_connection_summary,
          "h005" => h005_summary
        }
      end

      private

      attr_reader :tenant, :organization, :connection

      def active_connection_summary
        return unless connection

        { "id" => connection.id }.merge(
          connection.safe_summary.slice(
            "provider",
            "name",
            "active",
            "state",
            "health_status",
            "credential_keys",
            "settings"))
      end

      def h005_summary
        return unless connection&.ebics?

        {
          "admin_orders" => admin_order_summaries,
          "htd_btf_downloads" => htd_btf_downloads,
          "htd_btf_uploads" => htd_btf_uploads,
          "haa_available_downloads" => haa_available_downloads,
          "likely_payment_downloads" => likely_payment_downloads
        }
      end

      def admin_order_summaries
        @admin_order_summaries ||= ADMIN_ORDER_TYPES.index_with { |order_type| admin_order_summary(order_type) }
      end

      def admin_order_summary(order_type)
        result = btf_client.admin_order(order_type)
        data = AdminOrderData.new(result.order_data)

        {
          "status" => "ok",
          "receipt_sent" => result.receipt_sent,
          "order_infos" => data.order_infos,
          "services" => data.services,
          "legacy_order_types" => data.legacy_order_types
        }.compact_blank
      rescue NoDownloadDataAvailable
        {
          "status" => "no_data",
          "receipt_sent" => false,
          "order_infos" => [],
          "services" => [],
          "legacy_order_types" => []
        }
      rescue => e
        {
          "status" => "error",
          "class" => e.class.name,
          "message" => e.message
        }
      end

      def htd_btf_downloads
        htd_order_infos.select { |info| info["admin_order_type"] == "BTD" && info["service"].present? }
      end

      def htd_btf_uploads
        htd_order_infos.select { |info| info["admin_order_type"] == "BTU" && info["service"].present? }
      end

      def htd_order_infos
        admin_order_summaries.dig("HTD", "order_infos") || []
      end

      def haa_available_downloads
        admin_order_summaries.dig("HAA", "services") || []
      end

      def likely_payment_downloads
        (htd_btf_downloads.map { |info| info.fetch("service") } + haa_available_downloads)
          .select { |service| service["message_name"].to_s.start_with?("camt.") }
          .uniq
      end

      def btf_client
        @btf_client ||= BtfClient.new(
          connection.credentials,
          context: SafeContext.build(connection: connection))
      end

      class AdminOrderData
        def initialize(xml)
          @doc = Nokogiri::XML(xml)
        end

        def order_infos
          doc.xpath("//*[local-name() = 'OrderInfo'][*[local-name() = 'AdminOrderType']]").map do |node|
            {
              "admin_order_type" => text(node, "AdminOrderType"),
              "description" => text(node, "Description"),
              "num_sig_required" => integer_text(node, "NumSigRequired"),
              "service" => service_hash(node.at_xpath("./*[local-name() = 'Service']"))
            }.compact_blank
          end.uniq
        end

        def services
          doc.xpath("//*[local-name() = 'Service']").map { |node| service_hash(node) }.compact_blank.uniq
        end

        def legacy_order_types
          doc.xpath("//*[local-name() = 'OrderTypes']")
            .flat_map { |node| node.text.split }
            .uniq
            .sort
        end

        private
        attr_reader :doc

        def service_hash(node)
          return unless node

          {
            "service_name" => text(node, "ServiceName"),
            "scope" => text(node, "Scope"),
            "service_option" => text(node, "ServiceOption"),
            "container" => container(node),
            "message_name" => text(node, "MsgName"),
            "version" => child(node, "MsgName")&.[]("version")
          }.compact_blank
        end

        def container(node)
          container = child(node, "Container")
          container&.[]("containerType").presence || container&.text.presence
        end

        def integer_text(node, name)
          value = text(node, name)
          value.to_i if value.present?
        end

        def text(node, name)
          child(node, name)&.text.presence
        end

        def child(node, name)
          node&.at_xpath("./*[local-name() = '#{name}']")
        end
      end
    end
  end
end
