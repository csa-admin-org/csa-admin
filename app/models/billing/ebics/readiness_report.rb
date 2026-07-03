# frozen_string_literal: true

require "uri"

module Billing
  class EBICS
    class ReadinessReport
      REQUIRED_CREDENTIALS = %w[keys secret url host_id participant_id client_id]
      PARTICIPANT_KEY_VERSIONS = %w[A006 X002 E002]
      BANK_KEY_SUFFIXES = %w[.X002 .E002]

      def initialize(tenant:, organization: Current.org, connection: organization.active_bank_connection, live_hev: false, legacy_client: nil)
        @tenant = tenant
        @organization = organization
        @connection = connection
        @live_hev = live_hev
        @legacy_client = legacy_client
      end

      def to_h
        {
          "tenant" => tenant,
          "organization" => organization.name,
          "country_code" => organization.country_code,
          "legacy_connection" => legacy_connection_summary,
          "active_connection" => active_connection_summary,
          "last_import" => last_import_summary,
          "ebics" => ebics_summary
        }
      end

      private

      attr_reader :tenant, :organization, :connection, :live_hev

      def legacy_connection_summary
        {
          "provider" => organization.bank_connection_type,
          "credential_keys" => organization.bank_credentials.to_h.keys.map(&:to_s).sort
        }
      end

      def active_connection_summary
        return unless connection

        {
          "id" => connection.id,
          "provider" => connection.provider,
          "name" => connection.name,
          "active" => connection.active?,
          "state" => connection.state,
          "health_status" => connection.health_status,
          "credential_keys" => connection.credential_keys,
          "settings" => connection.settings,
          "last_import_attempted_at" => connection.last_import_attempted_at&.iso8601,
          "last_import_succeeded_at" => connection.last_import_succeeded_at&.iso8601,
          "last_no_data_at" => connection.last_no_data_at&.iso8601
        }
      end

      def last_import_summary
        return unless payment = Payment.import.reorder(created_at: :desc).first

        {
          "id" => payment.id,
          "origin" => payment.origin,
          "date" => payment.date&.iso8601,
          "created_at" => payment.created_at&.iso8601
        }
      end

      def ebics_summary
        return unless ebics?

        {
          "endpoint_host" => endpoint_host,
          "host_id" => ebics_credentials["host_id"],
          "key_summary" => key_summary,
          "hev" => hev_summary,
          "current_payment_operation" => operation_summary(current_payment_operation),
          "recommended_btf_payment_operation" => recommended_btf_payment_operation,
          "btf_readiness" => btf_readiness
        }
      end

      def ebics?
        connection&.ebics? || organization.bank_connection_type == "ebics"
      end

      def ebics_credentials
        @ebics_credentials ||= if connection&.ebics?
          connection.credentials.to_h.deep_stringify_keys
        else
          organization.bank_credentials.to_h.deep_stringify_keys
        end
      end

      def ebics_settings
        connection&.ebics? ? connection.settings : {}
      end

      def endpoint_host
        URI(ebics_credentials["url"]).host
      rescue URI::InvalidURIError
        nil
      end

      def key_summary
        @key_summary ||= if REQUIRED_CREDENTIALS.all? { |key| ebics_credentials[key].present? }
          Billing::EBICS::LegacyClient.new(ebics_credentials).key_summary
        else
          {}
        end
      rescue => e
        {
          "error" => {
            "class" => e.class.name,
            "message" => "Unable to inspect EBICS keys"
          }
        }
      end

      def hev_summary
        @hev_summary ||= begin
          if live_hev
            protocols = legacy_client.client.HEV
            {
              "status" => "ok",
              "protocols" => protocols
            }
          else
            skipped_hev_summary
          end
        rescue => e
          {
            "status" => "error",
            "class" => e.class.name,
            "message" => e.message
          }
        end
      end

      def skipped_hev_summary
        {
          "status" => "skipped",
          "reason" => "Set LIVE_HEV=true to query the bank"
        }
      end

      def legacy_client
        @legacy_client ||= Billing::EBICS::LegacyClient.new(ebics_credentials)
      end

      def current_payment_operation
        Billing::EBICS::OperationConfig.new(ebics_settings).payment_download
      rescue UnsupportedOperation => e
        {
          "error" => e.message
        }
      end

      def recommended_btf_payment_operation
        Billing::EBICS::Btf::Presets.payment_download(country_code: organization.country_code)
      rescue UnsupportedOperation => e
        {
          "error" => e.message
        }
      end

      def operation_summary(operation)
        return operation if operation.is_a?(Hash)

        operation.btf.merge("mode" => "btf")
      end

      def btf_readiness
        {
          "required_credentials_present" => required_credentials_present?,
          "participant_keys_present" => participant_keys_present?,
          "bank_public_keys_present" => bank_public_keys_present?,
          "key_size_ok" => key_size_ok?,
          "h005_confirmed" => h005_confirmed,
          "request_build_ready" => request_build_ready?,
          "live_dry_run_ready" => live_dry_run_ready?,
          "live_dry_run_blocker" => live_dry_run_blocker
        }
      end

      def required_credentials_present?
        REQUIRED_CREDENTIALS.all? { |key| ebics_credentials[key].present? }
      end

      def participant_keys_present?
        versions = key_summary.fetch("participant_key_versions", [])
        PARTICIPANT_KEY_VERSIONS.all? { |version| versions.include?(version) }
      end

      def bank_public_keys_present?
        versions = key_summary.fetch("bank_key_versions", [])
        BANK_KEY_SUFFIXES.all? { |suffix| versions.any? { |version| version.end_with?(suffix) } }
      end

      def key_size_ok?
        participant_bits = key_summary["participant_key_min_bits"]
        bank_bits = key_summary["bank_key_min_bits"]

        participant_bits.to_i >= 2048 && bank_bits.to_i >= 2048
      end

      def h005_confirmed
        return unless live_hev
        return false unless hev_summary["status"] == "ok"

        hev_summary.fetch("protocols", {}).key?("H005")
      end

      def request_build_ready?
        required_credentials_present? &&
          participant_keys_present? &&
          bank_public_keys_present? &&
          key_size_ok? &&
          !recommended_btf_payment_operation.key?("error")
      end

      def live_dry_run_ready?
        request_build_ready? && h005_confirmed == true
      end

      def live_dry_run_blocker
        return if live_dry_run_ready?
        return "Set LIVE_HEV=true to confirm H005 before live dry-run" unless live_hev
        return "Bank HEV does not confirm H005 support" unless h005_confirmed

        "BTF request cannot be built from current credentials/settings"
      end
    end
  end
end
