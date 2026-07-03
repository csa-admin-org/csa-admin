# frozen_string_literal: true

module Billing
  class EBICS
    class CapabilitiesMonitor
      Warning = Class.new(StandardError)
      SERVICE_KEYS = %w[service_name scope service_option container message_name version].freeze

      def initialize(connection: Current.org.active_bank_connection, report: nil, error_reporter: Rails.error)
        @connection = connection
        @report = report
        @error_reporter = error_reporter
        @warnings = []
      end

      def check!
        return unless connection&.ebics?

        report_admin_order_errors
        check_operation("payment_download", settings.dig("downloads", "payments"), advertised_download_services)
        check_operation("sepa_direct_debit_upload", sepa_direct_debit_upload_settings, advertised_upload_services) if monitor_sepa_direct_debit_upload?
        connection.mark_capabilities_checked!(
          report: report,
          status: warnings.any? ? "warning" : "healthy",
          warnings: warnings)
      rescue => e
        connection&.mark_error!(e, operation_kind: "capabilities_check")
        error_reporter.report(e, context: safe_context(operation_kind: "capabilities_check"))
        raise
      end

      private

      attr_reader :connection, :error_reporter, :warnings

      def report
        @report ||= CapabilitiesReport.new(
          tenant: Tenant.current,
          connection: connection).to_h
      end

      def settings
        @settings ||= connection.settings.to_h.deep_stringify_keys
      end

      def h005
        report.fetch("h005") { {} }
      end

      def previous_h005
        connection.capabilities.to_h.deep_stringify_keys.fetch("h005") { {} }
      end

      def sepa_direct_debit_upload_settings
        settings.dig("uploads", "sepa_direct_debit").to_h
      end

      def monitor_sepa_direct_debit_upload?
        Current.org.sepa_configured? && sepa_direct_debit_upload_settings.present?
      rescue
        false
      end

      def report_admin_order_errors
        h005.fetch("admin_orders") { {} }.each do |order_type, result|
          next unless result["status"] == "error"
          next if ignored_admin_order_error?(order_type, result)

          unexpected("EBICS capabilities admin-order check failed",
            admin_order_type: order_type,
            error_class: result["class"],
            error_message: result["message"],
            return_code: admin_order_return_code(result),
            report_text: result["report_text"])
        end
      end

      def check_operation(kind, config, advertised_services)
        config = config.to_h.deep_stringify_keys
        unless config["mode"] == "btf"
          unexpected("Active EBICS connection must use BTF operation settings",
            operation_kind: kind,
            operation: config.slice("mode", "btf"))
          return
        end

        btf = config.fetch("btf") { {} }.to_h.deep_stringify_keys
        service = service_tuple(btf)

        if service.blank?
          unexpected("Active EBICS connection has missing BTF operation settings", operation_kind: kind)
          return
        end

        return if advertised_services_unavailable?(advertised_services)

        unless configured_service_advertised?(service, advertised_services)
          unexpected("Configured EBICS BTF operation is no longer advertised",
            operation_kind: kind,
            operation: btf)
        end

        report_new_versions(kind, service, advertised_services)
      end

      def report_new_versions(kind, service, advertised_services)
        previous_versions = related_services(service, previous_advertised_services(kind))
          .filter_map { |advertised| advertised["version"].presence }
          .uniq
        return if previous_versions.empty?

        advertised_versions = related_services(service, advertised_services)
          .filter_map { |advertised| advertised["version"].presence }
          .uniq
        new_versions = advertised_versions - previous_versions
        return if new_versions.empty?

        unexpected("New EBICS BTF message version advertised",
          operation_kind: kind,
          operation: service,
          advertised_versions: new_versions)
      end

      def advertised_download_services
        htd_services(h005, "htd_btf_downloads") + h005.fetch("haa_available_downloads") { [] }
      end

      def advertised_upload_services
        htd_services(h005, "htd_btf_uploads")
      end

      def previous_advertised_services(kind)
        case kind
        when "payment_download"
          htd_services(previous_h005, "htd_btf_downloads") + previous_h005.fetch("haa_available_downloads") { [] }
        when "sepa_direct_debit_upload"
          htd_services(previous_h005, "htd_btf_uploads")
        else
          []
        end
      end

      def htd_services(source, key)
        source.fetch(key) { [] }.filter_map { |info| info["service"] }
      end

      def advertised_services_unavailable?(advertised_services)
        advertised_services.empty? && admin_order_errors?
      end

      def admin_order_errors?
        h005.fetch("admin_orders") { {} }.values.any? { |result| result["status"] == "error" }
      end

      def ignored_admin_order_error?(order_type, result)
        ignored_admin_order_return_codes(order_type).include?(admin_order_return_code(result))
      end

      def ignored_admin_order_return_codes(order_type)
        configured = settings.dig(
          "monitoring",
          "capabilities",
          "ignored_admin_order_return_codes")
        Array(configured.to_h[order_type.to_s.upcase]) + Array(configured.to_h["*"])
      end

      def admin_order_return_code(result)
        result["return_code"].presence || result["message"].to_s[/\A\d{6}/]
      end

      def configured_service_advertised?(service, advertised_services)
        related_services(service, advertised_services).any? { |advertised|
          service["version"].blank? || same_service?(advertised, service)
        }
      end

      def related_services(service, advertised_services)
        advertised_services.select { |advertised| same_service?(advertised.except("version"), service.except("version")) }
      end

      def same_service?(advertised, expected)
        service_tuple(advertised) == service_tuple(expected)
      end

      def service_tuple(attributes)
        attributes.to_h.deep_stringify_keys.slice(*SERVICE_KEYS).compact_blank
      end


      def unexpected(message, **context)
        warnings << message
        error_reporter.report(Warning.new(message),
          handled: false,
          severity: :error,
          context: warning_context(context),
          source: "ebics.capabilities_monitor")
      end

      def warning_context(context)
        safe_context(context).merge(
          appsignal: {
            namespace: "background",
            action: "EBICS capabilities monitor"
          })
      end

      def safe_context(context = {})
        SafeContext.build(connection: connection, **context)
      end
    end
  end
end
