# frozen_string_literal: true

require "digest"
require "fileutils"
require "openssl"
require "pathname"
require "uri"
require "securerandom"
require "time"

module Billing
  class EBICS
    class Onboarding
      TARGET_BITS = KeyMetadata::TARGET_BITS
      STATUS_DETAILS_KEY = "onboarding"
      PARTICIPANT_KEY_VERSIONS = KeyMetadata::PARTICIPANT_KEY_VERSIONS
      FINALIZATION_ORDER_TYPE = "HTD"
      REQUIRED_CREDENTIALS = KeyMetadata::REQUIRED_CREDENTIALS

      FINALIZATION_CLAIM_TIMEOUT = 15.minutes

      class ConcurrentSetup < UnsupportedOperation; end
      class InitializationClaimLost < UnsupportedOperation; end
      class FinalizationClaimLost < UnsupportedOperation; end

      def initialize(
        connection: nil,
        now: Time.current,
        error_reporter: Rails.error,
        key_generator: ->(bits) { OpenSSL::PKey::RSA.generate(bits) },
        version_probe_factory: -> { VersionProbe.new },
        btf_client_factory: ->(credentials, **options) { BtfClient.new(credentials, **options) },
        capabilities_report_factory: ->(tenant, connection) { CapabilitiesReport.new(tenant: tenant, connection: connection) },
        capabilities_monitor_factory: ->(connection, report) { CapabilitiesMonitor.new(connection: connection, report: report) })
        @tenant = Tenant.current
        @connection = connection
        @now = now
        @error_reporter = error_reporter
        @key_generator = key_generator
        @version_probe_factory = version_probe_factory
        @btf_client_factory = btf_client_factory
        @capabilities_report_factory = capabilities_report_factory
        @capabilities_monitor_factory = capabilities_monitor_factory
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

      def initialize_connection!(url:, host_id:, client_id:, participant_id:, name: nil, target_bits: TARGET_BITS)
        raise UnsupportedOperation, "EBICS onboarding url is required" if url.blank?
        raise UnsupportedOperation, "EBICS onboarding host_id is required" if host_id.blank?
        raise UnsupportedOperation, "EBICS onboarding client_id is required" if client_id.blank?
        raise UnsupportedOperation, "EBICS onboarding participant_id is required" if participant_id.blank?
        raise UnsupportedOperation, "EBICS onboarding url must be a valid HTTPS URL" unless https_url?(url)
        raise UnsupportedOperation, "EBICS onboarding is already initialized for this bank connection" if initialized?
        raise UnsupportedOperation, "Ready EBICS bank connections cannot be reinitialized" if connection&.ready?

        target_bits = target_bits.to_i
        raise UnsupportedOperation, "EBICS onboarding target key size must be at least 2048 bits" if target_bits < 2048

        check_version!(url: url, host_id: host_id)
        raise ConcurrentSetup, "An EBICS onboarding setup is already in progress" if another_onboarding_in_progress?

        credentials = initial_credentials(
          url: url,
          host_id: host_id,
          client_id: client_id,
          participant_id: participant_id,
          target_bits: target_bits)
        status = {
          "state" => "initialized",
          "target_bits" => target_bits,
          "host_id" => host_id,
          "protocol" => "H005",
          "initialized_at" => now.iso8601,
          "certificate_issued_at" => now.utc.iso8601,
          "keys" => split_key_metadata(KeyStore.new(credentials).key_metadata)
        }

        @connection = connection || BankConnection.new(provider: "ebics", active: false)
        persist_initialization!(
          credentials: credentials,
          host_id: host_id,
          name: name,
          status: status)

        clear_connection_memoization!
        refreshed.status.merge("initialized" => true)
      rescue ConcurrentSetup, UnsupportedOperation
        raise
      rescue ActiveRecord::RecordNotUnique
        @connection = nil unless connection&.persisted?
        raise ConcurrentSetup, "An EBICS onboarding setup is already in progress"
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
        finalization_claim_token = claim_finalization_check!(record_blocked: false, respect_daily_limit: false)
        return finalization_claim_result(finalization_claim_token) unless finalization_claim_token.is_a?(String)

        perform_finalization!(finalization_claim_token)
      rescue FinalizationClaimLost
        finalization_claim_lost_result
      rescue => error
        raise unless finalization_claim_token

        record_finalization_error!(error, finalization_claim_token, stage: "finalize")
      end

      def check_finalization!
        finalization_claim_token = claim_finalization_check!(record_blocked: true, respect_daily_limit: true)
        return finalization_claim_result(finalization_claim_token) unless finalization_claim_token.is_a?(String)

        perform_finalization!(finalization_claim_token)
      rescue FinalizationClaimLost
        finalization_claim_lost_result
      rescue => error
        record_finalization_error!(error, finalization_claim_token, stage: "check_finalization")
      end

      private

      attr_reader :tenant, :now, :error_reporter, :key_generator, :version_probe_factory, :btf_client_factory,
        :capabilities_report_factory, :capabilities_monitor_factory

      def claim_initialization_order!(order_type)
        raise UnsupportedOperation, submission_blockers(order_type).to_sentence unless connection&.persisted?

        connection.with_lock do
          clear_connection_memoization!
          submitted_key = "#{order_type.downcase}_submitted_at"

          if recorded_status[submitted_key].present?
            status.merge("submitted" => false, "message" => "#{order_type} already submitted")
          else
            blockers = submission_blockers(order_type)
            raise UnsupportedOperation, blockers.to_sentence if blockers.present?

            claim_token = SecureRandom.uuid
            update_onboarding!(onboarding_status("submitting_#{order_type.downcase}").merge(
              "#{order_type.downcase}_submit_started_at" => now.iso8601,
              "#{order_type.downcase}_submit_claim_token" => claim_token))
            claim_token
          end
        end
      end

      def claim_finalization_check!(record_blocked:, respect_daily_limit:)
        unless connection&.persisted?
          blockers = finalization_blockers
          raise UnsupportedOperation, blockers.to_sentence unless record_blocked

          return record_finalization_check!("blocked", message: blockers.to_sentence)
        end

        connection.with_lock do
          clear_connection_memoization!

          if finalized?
            :finalized
          elsif finalization_in_progress?
            :in_progress
          elsif respect_daily_limit && finalization_checked_today?
            :already_checked
          elsif (blockers = finalization_blockers).present?
            if record_blocked
              record_finalization_check!("blocked", message: blockers.to_sentence, locked: true)
            else
              raise UnsupportedOperation, blockers.to_sentence
            end
          else
            claim_token = SecureRandom.uuid
            update_onboarding!(onboarding_status("finalizing").merge(
              "finalize_started_at" => now.iso8601,
              "finalization_claim_token" => claim_token,
              "last_finalization_check_at" => now.iso8601,
              "last_finalization_status" => "checking"))
            claim_token
          end
        end
      end

      def finalization_claim_result(claim)
        case claim
        when :finalized
          status.merge("checked" => false, "finalized" => false, "message" => "EBICS onboarding already finalized")
        when :in_progress
          status.merge("checked" => false, "finalized" => false, "message" => "EBICS onboarding finalization is already in progress")
        when :already_checked
          status.merge("checked" => false, "finalized" => false, "message" => "EBICS onboarding finalization already checked today")
        else
          claim
        end
      end

      def finalization_claim_lost_result
        status.merge(
          "checked" => false,
          "finalized" => false,
          "message" => "EBICS onboarding finalization was completed or retried by another process")
      end

      def finalization_checked_today?
        checked_at = recorded_status["last_finalization_check_at"]
        checked_at.present? && Time.iso8601(checked_at).to_date >= now.to_date
      rescue ArgumentError
        false
      end

      def finalization_in_progress?
        recorded_status["state"] == "finalizing" && !stale_finalization_claim?
      end

      def stale_finalization_claim?
        started_at = Time.iso8601(recorded_status.fetch("finalize_started_at"))
        started_at <= FINALIZATION_CLAIM_TIMEOUT.ago
      rescue ArgumentError, KeyError
        true
      end

      def finalization_claim_owned?(claim_token)
        recorded_status["state"] == "finalizing" &&
          recorded_status["finalization_claim_token"] == claim_token
      end

      def submit_initialization_order!(order_type)
        claim_token = claim_initialization_order!(order_type)
        return claim_token unless claim_token.is_a?(String)

        result = bootstrap_client.submit_initialization_order(order_type)
        complete_initialization_order!(order_type, claim_token, result)

        refreshed.status.merge("submitted" => true, "result" => result.to_h)
      rescue InitializationClaimLost
        initialization_claim_lost_result(order_type)
      rescue UnsupportedOperation
        raise
      rescue => error
        fail_safely!(
          error,
          stage: "submit_#{order_type.downcase}",
          initialization_claim: [ order_type, claim_token ])
      end

      def complete_initialization_order!(order_type, claim_token, result)
        submitted_key = "#{order_type.downcase}_submitted_at"
        new_state = order_type == "HIA" ? "waiting_for_bank" : "ini_submitted"
        connection_state = order_type == "HIA" ? "waiting_for_bank" : "initializing"

        connection.with_lock do
          clear_connection_memoization!
          raise InitializationClaimLost unless initialization_claim_owned?(order_type, claim_token)

          update_onboarding!(
            onboarding_status(new_state).merge(
              submitted_key => now.iso8601,
              "#{order_type.downcase}_result" => result.to_h),
            connection_state: connection_state,
            clear_initialization_claim: order_type)
        end
      end

      def initialization_claim_lost_result(order_type)
        status.merge(
          "submitted" => false,
          "message" => "#{order_type} submission was completed or retried by another process")
      end

      def initialization_claim_owned?(order_type, claim_token)
        recorded_status["state"] == "submitting_#{order_type.downcase}" &&
          recorded_status["#{order_type.downcase}_submit_claim_token"] == claim_token
      end

      def perform_finalization!(finalization_claim_token)
        bank_public_keys = bootstrap_client.fetch_bank_public_keys
        final_credentials = credentials_with_bank_keys(bank_public_keys.keys.keys)
        verification = finalized_client(final_credentials).admin_order(FINALIZATION_ORDER_TYPE)
        event_id = SecureRandom.uuid

        connection.with_lock do
          clear_connection_memoization!
          raise FinalizationClaimLost unless finalization_claim_owned?(finalization_claim_token)

          status_details = merged_status_details(onboarding_status("finalized").merge(
            "finalized_at" => now.iso8601,
            "last_finalization_check_at" => now.iso8601,
            "last_finalization_status" => "finalized",
            "finalization_notification_event_id" => event_id,
            "bank_keys" => bank_public_keys.keys.metadata,
            "verification_order_type" => FINALIZATION_ORDER_TYPE,
            "verification_receipt_sent" => verification.receipt_sent))
          status_details.fetch("onboarding").except!("finalization_claim_token", "finalize_started_at")

          connection.update!(
            active: true,
            credentials: final_credentials,
            state: "ready",
            health_status: "healthy",
            last_health_check_at: now,
            last_error_class: nil,
            last_error_message: nil,
            status_details: status_details)
          BankConnection::FinalizationNotification.create_for_finalization!(
            bank_connection: connection,
            event_id: event_id)
        end
        check_capabilities_after_finalization!

        refreshed.status.merge("checked" => true, "finalized" => true)
      end

      def check_capabilities_after_finalization!
        report = capabilities_report_factory.call(tenant, connection).to_h
        capabilities_monitor_factory.call(connection, report).check!
      rescue => e
        report_unexpected(e, stage: "capabilities_after_finalization")
      end

      def record_finalization_check!(status, message: nil, error: nil, finalization_claim_token: nil, locked: false)
        return self.status.merge(
          "checked" => true,
          "finalized" => false,
          "finalization_status" => status,
          "message" => message || finalization_message_for(status)) unless connection&.persisted?

        details = {
          "last_finalization_check_at" => now.iso8601,
          "last_finalization_status" => status,
          "finalization_message" => message || finalization_message_for(status)
        }.merge(finalization_error_summary(error))
        record_check = lambda do
          clear_connection_memoization!
          next :claim_lost if finalization_claim_token && !finalization_claim_owned?(finalization_claim_token)

          update_onboarding!(
            onboarding_status(finalization_check_state).merge(details),
            clear_finalization_claim: finalization_claim_token.present?)
          :recorded
        end
        result = locked ? record_check.call : connection.with_lock(&record_check)
        return finalization_claim_lost_result if result == :claim_lost

        refreshed.status.merge(
          "checked" => true,
          "finalized" => false,
          "finalization_status" => status,
          "message" => details.fetch("finalization_message"))
      end

      def record_finalization_error!(error, claim_token, stage:)
        status = finalization_not_ready_error?(error) ? "not_ready" : "error"
        result = record_finalization_check!(status, error: error, finalization_claim_token: claim_token)
        report_unexpected(error, stage: stage) if status == "error"
        result
      end

      def finalization_check_state
        status = recorded_status["state"].presence
        status == "finalizing" ? connection.state : (status || connection.state)
      end

      def finalization_message_for(status)
        case status
        when "not_ready"
          "The bank has not activated the EBICS setup yet"
        when "error"
          "EBICS onboarding finalization check failed unexpectedly"
        else
          "EBICS onboarding finalization check was not run"
        end
      end

      def finalization_error_summary(error)
        return {} unless error

        response = finalization_error_response(error)
        report_text = response&.report_text.to_s
        summary = {
          "finalization_error_class" => error.class.name,
          "finalization_return_code" => response&.return_code
        }
        if report_text.present?
          summary.merge!(
            "finalization_report_text_length" => report_text.bytesize,
            "finalization_report_text_sha256" => Digest::SHA256.hexdigest(report_text))
        end

        summary.compact_blank
      end

      def finalization_error_response(error)
        original = error.respond_to?(:original_error) ? error.original_error : error
        original.response if original.respond_to?(:response)
      end

      def finalization_not_ready_error?(error)
        error.is_a?(ClientError) ||
          error.is_a?(BtfClient::AdminOrderDataError) ||
          error.is_a?(UnsupportedOperation)
      end

      def check_version!(url:, host_id:)
        version_probe_factory.call.check!(url: url, host_id: host_id)
      end

      def persist_initialization!(credentials:, host_id:, name:, status:)
        if connection.persisted?
          connection.with_lock do
            clear_connection_memoization!
            raise UnsupportedOperation, "EBICS onboarding is already initialized for this bank connection" if initialized?
            raise ConcurrentSetup, "An EBICS onboarding setup is already in progress" if another_onboarding_in_progress?

            update_initialized_connection!(credentials: credentials, host_id: host_id, name: name, status: status)
          end
        else
          update_initialized_connection!(credentials: credentials, host_id: host_id, name: name, status: status)
        end
      end

      def update_initialized_connection!(credentials:, host_id:, name:, status:)
        connection.update!(
          provider: "ebics",
          name: name.presence || host_id,
          active: false,
          state: "initializing",
          health_status: "unknown",
          credentials: credentials,
          settings: ebics_settings_for(connection).merge("protocol" => "H005"),
          status_details: merged_status_details_for(connection, status))
      end

      def initial_credentials(url:, host_id:, client_id:, participant_id:, target_bits:)
        secret = SecureRandom.base64(48)
        keys = PARTICIPANT_KEY_VERSIONS.index_with { generate_key(target_bits) }

        {
          "keys" => KeyStore.encrypt_keys(keys, secret),
          "secret" => secret,
          "url" => url,
          "host_id" => host_id,
          "participant_id" => participant_id,
          "client_id" => client_id
        }
      end

      def generate_key(bits)
        key = key_generator.call(bits)
        key.respond_to?(:key) ? key.key : key
      end

      def https_url?(value)
        uri = URI.parse(value)
        uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?
      rescue URI::InvalidURIError
        false
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
        values << "INI and HIA must be submitted before generating the initialization letter" unless setup_orders_submitted?
        values << "EBICS onboarding must be waiting for bank activation before generating the initialization letter" unless connection&.waiting_for_bank?
        values
      end

      def finalization_blockers
        values = blockers.dup
        values << "EBICS onboarding must be initialized first" unless initialized?
        values << "HIA must be submitted before HPB finalization" if recorded_status["hia_submitted_at"].blank?
        values << "Another bank connection is already active" if another_active_connection?
        values
      end

      def submission_uncertain?(order_type)
        key = order_type.downcase
        recorded_status["#{key}_submit_started_at"].present? && recorded_status["#{key}_submitted_at"].blank?
      end

      def initialized?
        connection&.ebics? && ebics_credentials["keys"].present? && ebics_credentials["secret"].present? && recorded_status.present?
      end

      def setup_orders_submitted?
        recorded_status["ini_submitted_at"].present? && recorded_status["hia_submitted_at"].present?
      end

      def another_active_connection?
        return false unless connection&.persisted?

        BankConnection.active.where.not(id: connection.id).exists?
      end

      def another_onboarding_in_progress?
        BankConnection.where(
          provider: "ebics",
          active: false,
          state: %w[initializing waiting_for_bank errored]
        ).where.not(id: connection&.id).exists?
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
        KeyMetadata.split(metadata)
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

      def update_onboarding!(status, connection_state: nil, clear_finalization_claim: false, clear_initialization_claim: nil)
        status_details = merged_status_details(status)
        onboarding = status_details.fetch(STATUS_DETAILS_KEY)
        onboarding.except!("finalization_claim_token", "finalize_started_at") if clear_finalization_claim
        onboarding.delete("#{clear_initialization_claim.downcase}_submit_claim_token") if clear_initialization_claim

        attributes = { status_details: status_details }
        attributes[:state] = connection_state if connection_state
        connection.update!(attributes)
        clear_connection_memoization!
      end

      def clear_connection_memoization!
        %i[@recorded_status @ebics_credentials @ebics_settings @key_store @key_error_message].each do |name|
          remove_instance_variable(name) if instance_variable_defined?(name)
        end
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
          connection: connection.reload,
          now: now,
          error_reporter: error_reporter,
          key_generator: key_generator,
          version_probe_factory: version_probe_factory,
          btf_client_factory: btf_client_factory,
          capabilities_report_factory: capabilities_report_factory,
          capabilities_monitor_factory: capabilities_monitor_factory)
      end

      def fail_safely!(error, stage:, finalization_claim_token: nil, initialization_claim: nil)
        record_failure!(
          error,
          stage: stage,
          finalization_claim_token: finalization_claim_token,
          initialization_claim: initialization_claim)
        raise UnsupportedOperation, "EBICS onboarding failed during #{stage}; inspect sanitized onboarding status and error reporting context"
      end

      def record_failure!(error, stage:, finalization_claim_token: nil, initialization_claim: nil)
        return unless connection&.persisted?

        failure_error = recorded_error(error)
        record_failure = lambda do
          status_details = merged_status_details(onboarding_status("errored").merge(
            "stage" => stage,
            "failed_at" => now.iso8601,
            "error_class" => failure_error.class.name,
            "error_message" => "EBICS onboarding failed during #{stage}"))
          onboarding = status_details.fetch(STATUS_DETAILS_KEY)
          onboarding.except!("finalization_claim_token", "finalize_started_at") if finalization_claim_token
          onboarding.delete("#{initialization_claim.first.downcase}_submit_claim_token") if initialization_claim

          connection.update_columns(
            state: "errored",
            health_status: "errored",
            last_error_class: failure_error.class.name,
            last_error_message: "EBICS onboarding failed during #{stage}",
            status_details: status_details,
            updated_at: now)
        end

        if finalization_claim_token || initialization_claim
          connection.with_lock do
            clear_connection_memoization!
            owns_claim = finalization_claim_token ?
              finalization_claim_owned?(finalization_claim_token) :
              initialization_claim_owned?(*initialization_claim)
            record_failure.call if owns_claim
          end
        else
          record_failure.call
        end
        report_unexpected(error, stage: stage)
      rescue => reporter_error
        error_reporter.report(reporter_error, context: safe_context(stage: "record_failure"))
      end

      def recorded_error(error)
        if error.respond_to?(:original_error) && error.original_error.is_a?(BtfClient::InvalidResponseError)
          error.original_error
        else
          error
        end
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
