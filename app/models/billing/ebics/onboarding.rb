# frozen_string_literal: true

require "digest"
require "fileutils"
require "openssl"
require "pathname"
require "securerandom"
require "time"

module Billing
  class EBICS
    class Onboarding
      TARGET_BITS = 4096
      STATUS_DETAILS_KEY = "onboarding"
      PARTICIPANT_KEY_VERSIONS = %w[A006 X002 E002].freeze
      FINALIZATION_ORDER_TYPE = "HTD"
      REQUIRED_CREDENTIALS = %w[keys secret url host_id participant_id client_id].freeze

      def initialize(tenant:, connection: nil, now: Time.current, error_reporter: Rails.error, key_generator: ->(bits) { OpenSSL::PKey::RSA.generate(bits) }, btf_client_factory: ->(credentials, **options) { BtfClient.new(credentials, **options) })
        @tenant = tenant
        @connection = connection
        @now = now
        @error_reporter = error_reporter
        @key_generator = key_generator
        @btf_client_factory = btf_client_factory
      end

      attr_reader :connection

      def status
        {
          "tenant" => tenant,
          "state" => state,
          "target_bits" => target_bits,
          "blockers" => blockers,
          "bank_connection" => bank_connection_summary,
          "group" => group,
          "protocol" => ebics_settings["protocol"],
          "participant_keys" => participant_key_summary,
          "bank_keys" => bank_key_summary,
          "certificate_hashes" => certificate_hashes,
          "recorded_status" => recorded_status
        }.compact_blank
      end

      def initialize_connection!(url:, host_id:, partner_id:, user_id:, name: nil, target_bits: TARGET_BITS)
        raise UnsupportedOperation, "EBICS onboarding is already initialized for this bank connection" if initialized?
        raise UnsupportedOperation, "Ready EBICS bank connections cannot be reinitialized" if connection&.ready?

        target_bits = target_bits.to_i
        raise UnsupportedOperation, "EBICS onboarding target key size must be at least 2048 bits" if target_bits < 2048

        credentials = initial_credentials(
          url: url,
          host_id: host_id,
          partner_id: partner_id,
          user_id: user_id,
          target_bits: target_bits)
        status = onboarding_status("initialized").merge(
          "initialized_at" => now.iso8601,
          "certificate_issued_at" => now.utc.iso8601,
          "target_bits" => target_bits,
          "keys" => split_key_metadata(KeyStore.new(credentials).key_metadata))

        @connection = (connection || BankConnection.new(provider: "ebics", active: false)).tap do |record|
          record.update!(
            provider: "ebics",
            name: name.presence || host_id,
            active: false,
            state: "initializing",
            health_status: "unknown",
            credentials: credentials,
            settings: ebics_settings_for(record).merge("protocol" => "H005"),
            status_details: merged_status_details_for(record, status))
        end

        refreshed.status.merge("initialized" => true)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "initialize")
      end

      def submit_ini!
        submit_initialization_order!("INI")
      end

      def submit_hia!
        submit_initialization_order!("HIA")
      end

      def letter_available?
        letter_blockers.empty?
      end

      def write_letter!(output:, locale: I18n.locale)
        raise UnsupportedOperation, letter_blockers.to_sentence if letter_blockers.present?

        path = Pathname.new(output.to_s)
        path = Rails.root.join(path) unless path.absolute?
        FileUtils.mkdir_p(path.dirname)

        I18n.with_locale(locale) do
          path.binwrite(PDF::EBICSInitializationLetter.new(connection, generated_at: certificate_issued_at).render)
        end

        status.merge("letter" => {
          "path" => path.to_s,
          "locale" => locale.to_s
        })
      end

      def finalize!
        return status.merge("finalized" => false, "message" => "EBICS onboarding already finalized") if finalized?

        raise UnsupportedOperation, finalization_blockers.to_sentence if finalization_blockers.present?

        update_onboarding!(onboarding_status("finalizing").merge("finalize_started_at" => now.iso8601))

        bank_public_keys = bootstrap_client.fetch_bank_public_keys
        final_credentials = credentials_with_bank_keys(bank_public_keys.keys.keys)
        verification = finalized_client(final_credentials).admin_order(FINALIZATION_ORDER_TYPE)

        connection.update!(
          credentials: final_credentials,
          state: "ready",
          health_status: "healthy",
          last_health_check_at: now,
          last_error_class: nil,
          last_error_message: nil,
          status_details: merged_status_details(onboarding_status("finalized").merge(
            "finalized_at" => now.iso8601,
            "bank_keys" => bank_public_keys.keys.metadata,
            "verification_order_type" => FINALIZATION_ORDER_TYPE,
            "verification_receipt_sent" => verification.receipt_sent)))

        refreshed.status.merge("finalized" => true)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "finalize")
      end

      private

      attr_reader :tenant, :now, :error_reporter, :key_generator, :btf_client_factory

      def submit_initialization_order!(order_type)
        submitted_key = "#{order_type.downcase}_submitted_at"
        return status.merge("submitted" => false, "message" => "#{order_type} already submitted") if recorded_status[submitted_key].present?

        blockers = submission_blockers(order_type)
        raise UnsupportedOperation, blockers.to_sentence if blockers.present?

        update_onboarding!(onboarding_status("submitting_#{order_type.downcase}").merge(
          "#{order_type.downcase}_submit_started_at" => now.iso8601))

        result = bootstrap_client.submit_initialization_order(order_type)
        new_state = order_type == "HIA" ? "waiting_for_bank" : "ini_submitted"
        connection_state = order_type == "HIA" ? "waiting_for_bank" : "initializing"
        update_onboarding!(
          onboarding_status(new_state).merge(
            submitted_key => now.iso8601,
            "#{order_type.downcase}_result" => result.to_h),
          connection_state: connection_state)

        refreshed.status.merge("submitted" => true, "result" => result.to_h)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "submit_#{order_type.downcase}")
      end

      def initial_credentials(url:, host_id:, partner_id:, user_id:, target_bits:)
        secret = SecureRandom.base64(48)
        keys = PARTICIPANT_KEY_VERSIONS.index_with { generate_key(target_bits) }

        {
          "keys" => KeyStore.encrypt_keys(keys, secret),
          "secret" => secret,
          "url" => url,
          "host_id" => host_id,
          "participant_id" => user_id,
          "client_id" => partner_id
        }
      end

      def generate_key(bits)
        key = key_generator.call(bits)
        key.respond_to?(:key) ? key.key : key
      end

      def state
        return "missing_connection" unless connection
        return "blocked" unless connection.ebics?
        return recorded_status.fetch("state") if recorded_status["state"].present?
        return "ready" if connection.ready?

        connection.state
      end

      def blockers
        return [ "No EBICS bank connection" ] unless connection
        return [ "Bank connection is not EBICS" ] unless connection.ebics?

        [].tap do |values|
          values << "EBICS onboarding requires protocol H005" if ebics_settings["protocol"].present? && ebics_settings["protocol"] != "H005"
          missing_credentials.each { |key| values << "Missing EBICS credential: #{key}" } if initialized?
          values << key_error_message if key_error_message
        end.compact
      end

      def submission_blockers(order_type)
        values = blockers.dup
        values << "EBICS onboarding must be initialized first" unless initialized?
        values << "INI must be submitted before HIA" if order_type == "HIA" && recorded_status["ini_submitted_at"].blank?
        values << "#{order_type} submission has an uncertain outcome; inspect onboarding status before retrying" if submission_uncertain?(order_type)
        values
      end

      def letter_blockers
        values = blockers.dup
        values << "EBICS onboarding must be initialized before generating the initialization letter" unless initialized?
        values
      end

      def finalization_blockers
        values = blockers.dup
        values << "EBICS onboarding must be initialized first" unless initialized?
        values << "HIA must be submitted before HPB finalization" if recorded_status["hia_submitted_at"].blank?
        values
      end

      def submission_uncertain?(order_type)
        key = order_type.downcase
        recorded_status["#{key}_submit_started_at"].present? && recorded_status["#{key}_submitted_at"].blank?
      end

      def initialized?
        connection&.ebics? && ebics_credentials["keys"].present? && ebics_credentials["secret"].present? && recorded_status.present?
      end

      def finalized?
        connection&.ready? && recorded_status["state"] == "finalized"
      end

      def missing_credentials
        REQUIRED_CREDENTIALS.reject { |key| ebics_credentials[key].present? }
      end

      def key_error_message
        key_store
        @key_error_message
      end

      def participant_key_summary
        return unless initialized?
        return { "error" => key_error_message } if key_error_message

        split_key_metadata(key_store.key_metadata).fetch("participant")
      end

      def bank_key_summary
        return unless initialized?
        return { "error" => key_error_message } if key_error_message

        split_key_metadata(key_store.key_metadata).fetch("bank")
      end

      def certificate_hashes
        return unless initialized?
        return if key_error_message

        certificate_versions.index_with do |version|
          certificate = certificate_for(version)
          {
            "sha256" => fingerprint(certificate),
            "subject" => certificate.subject.to_s
          }
        end
      end

      def certificate_versions
        key_store.keys.keys & PARTICIPANT_KEY_VERSIONS
      end

      def certificate_for(version)
        Btf::KeyChangeOrderData::CertificateBuilder.new.certificate_for(
          key_store.keys.fetch(version).key,
          version: version,
          client: key_store,
          now: certificate_issued_at)
      end

      def fingerprint(certificate)
        Digest::SHA256.hexdigest(certificate.to_der).upcase.scan(/../).join(":")
      end

      def key_store
        @key_store ||= KeyStore.new(ebics_credentials)
      rescue => e
        @key_error_message = "Unable to inspect EBICS onboarding keys"
        report_unexpected(e, stage: "key_summary")
        nil
      end

      def split_key_metadata(metadata)
        {
          "participant" => metadata.reject { |name, _attributes| name.include?(".") },
          "bank" => metadata.select { |name, _attributes| name.include?(".") }
        }
      end

      def credentials_with_bank_keys(bank_keys)
        keys = key_store.keys.slice(*PARTICIPANT_KEY_VERSIONS).merge(bank_keys).transform_values do |key|
          key.respond_to?(:key) ? key.key : key
        end
        ebics_credentials.merge("keys" => KeyStore.encrypt_keys(keys, ebics_credentials.fetch("secret")))
      end

      def bootstrap_client
        btf_client_for(ebics_credentials, verify_signatures: false)
      end

      def finalized_client(credentials)
        btf_client_for(credentials, verify_signatures: true)
      end

      def btf_client_for(credentials, verify_signatures:)
        btf_client_factory.call(
          credentials,
          request_options: { certificate_issued_at: certificate_issued_at },
          verify_signatures: verify_signatures,
          context: safe_context(stage: "onboarding"))
      end

      def bank_connection_summary
        return unless connection

        {
          "id" => connection.id,
          "provider" => connection.provider,
          "name" => connection.name,
          "active" => connection.active?,
          "state" => connection.state,
          "health_status" => connection.health_status
        }
      end

      def group
        return unless connection

        {
          "tenant" => tenant,
          "host_id" => ebics_credentials["host_id"],
          "endpoint_url" => ebics_credentials["url"]
        }.compact_blank
      end

      def update_onboarding!(status, connection_state: nil)
        attributes = { status_details: merged_status_details(status) }
        attributes[:state] = connection_state if connection_state
        connection.update!(attributes)
      end

      def onboarding_status(state)
        {
          "state" => state,
          "target_bits" => target_bits,
          "host_id" => ebics_credentials["host_id"],
          "protocol" => "H005"
        }.compact_blank
      end

      def target_bits
        recorded_status["target_bits"] || TARGET_BITS
      end

      def recorded_status
        @recorded_status ||= connection&.status_details.to_h.dig(STATUS_DETAILS_KEY).to_h.deep_stringify_keys
      end

      def merged_status_details(status)
        merged_status_details_for(connection, status)
      end

      def merged_status_details_for(record, status)
        current = record.status_details.to_h.deep_stringify_keys
        previous = current.fetch(STATUS_DETAILS_KEY) { {} }.to_h
        current.merge(STATUS_DETAILS_KEY => previous.merge(status).compact_blank)
      end

      def ebics_credentials
        @ebics_credentials ||= connection&.credentials.to_h.deep_stringify_keys
      end

      def ebics_settings
        @ebics_settings ||= ebics_settings_for(connection)
      end

      def ebics_settings_for(record)
        record&.settings.to_h.deep_stringify_keys
      end

      def certificate_issued_at
        Time.iso8601(recorded_status["certificate_issued_at"].presence || recorded_status["initialized_at"].presence || now.utc.iso8601)
      end

      def refreshed
        self.class.new(
          tenant: tenant,
          connection: connection.reload,
          now: now,
          error_reporter: error_reporter,
          key_generator: key_generator,
          btf_client_factory: btf_client_factory)
      end

      def fail_safely!(error, stage:)
        record_failure!(error, stage: stage)
        raise UnsupportedOperation, "EBICS onboarding failed during #{stage}; inspect sanitized onboarding status and error reporting context"
      end

      def record_failure!(error, stage:)
        return unless connection&.persisted?

        connection.update_columns(
          state: "errored",
          health_status: "errored",
          last_error_class: error.class.name,
          last_error_message: "EBICS onboarding failed during #{stage}",
          status_details: merged_status_details(onboarding_status("errored").merge(
            "stage" => stage,
            "failed_at" => Time.current.iso8601,
            "error_class" => error.class.name,
            "error_message" => "EBICS onboarding failed during #{stage}")),
          updated_at: Time.current)
        report_unexpected(error, stage: stage)
      rescue => reporter_error
        error_reporter.report(reporter_error, context: safe_context(stage: "record_failure"))
      end

      def report_unexpected(error, stage:)
        error_reporter.report(error, context: safe_context(stage: stage))
      rescue
        nil
      end

      def safe_context(stage:)
        connection&.safe_context(operation_kind: "ebics_onboarding", stage: stage) || {
          "tenant" => tenant,
          "operation_kind" => "ebics_onboarding",
          "stage" => stage
        }
      end
    end
  end
end
