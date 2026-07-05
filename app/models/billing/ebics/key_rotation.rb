# frozen_string_literal: true

require "digest"
require "openssl"
require "uri"

module Billing
  class EBICS
    class KeyRotation
      TARGET_BITS = 4096
      ROTATION_ORDER_TYPE = "HCS"
      VERIFICATION_ORDER_TYPE = "HTD"
      REQUIRED_CREDENTIALS = %w[keys secret url host_id participant_id client_id].freeze
      PARTICIPANT_KEY_VERSIONS = %w[A006 X002 E002].freeze
      BANK_KEY_SUFFIXES = %w[.X002 .E002].freeze
      KEY_MANAGEMENT_ORDER_TYPES = %w[H3K HCA HCS HIA HPB INI PUB].freeze
      PENDING_CREDENTIAL_KEY = "pending_key_rotation"
      PREVIOUS_CREDENTIAL_KEY = "previous_key_rotation"
      STATUS_DETAILS_KEY = "key_rotation"

      def initialize(tenant:, connection: Current.org.active_bank_connection, now: Time.current, error_reporter: Rails.error, key_generator: -> { OpenSSL::PKey::RSA.generate(TARGET_BITS) }, btf_client_factory: ->(credentials, **options) { BtfClient.new(credentials, **options) })
        @tenant = tenant
        @connection = connection
        @now = now
        @error_reporter = error_reporter
        @key_generator = key_generator
        @btf_client_factory = btf_client_factory
      end

      def readiness
        {
          "tenant" => tenant,
          "group" => group,
          "target_bits" => TARGET_BITS,
          "state" => state,
          "blockers" => blockers,
          "bank_connection" => bank_connection_summary,
          "protocol" => ebics_settings["protocol"],
          "h005_configured" => h005_configured?,
          "rotation_strategy" => rotation_strategy,
          "advertised_key_management" => advertised_key_management_order_types,
          "active_keys" => active_key_summary,
          "pending_rotation" => pending_summary,
          "previous_rotation" => previous_summary,
          "recorded_status" => recorded_status
        }.compact
      end

      def prepare_pending!
        return readiness.merge("prepared" => false, "message" => "Participant keys are already at #{TARGET_BITS} bits") if already_at_target?
        return readiness.merge("prepared" => false, "message" => "Pending key rotation already exists") if pending_keys_json.present?

        raise UnsupportedOperation, prepare_blockers.to_sentence if prepare_blockers.present?

        pending_keys = generated_participant_keys.merge(active_key_store.bank_key_material)
        pending_metadata = key_metadata_for(pending_keys)
        pending = {
          "state" => "prepared",
          "target_bits" => TARGET_BITS,
          "created_at" => now.iso8601,
          "keys" => KeyStore.encrypt_keys(pending_keys, ebics_credentials.fetch("secret"))
        }
        update_connection!(
          credentials: ebics_credentials.merge(PENDING_CREDENTIAL_KEY => pending),
          status: pending_status("pending_rotation").merge(
            "prepared_at" => now.iso8601,
            "active_keys" => active_key_summary,
            "pending_keys" => split_key_metadata(pending_metadata)))

        refreshed.readiness.merge("prepared" => true)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "prepare")
      end

      def request_build_validation
        validation_blockers = submission_blockers(require_submitted: false)
        request = build_request_metadata if validation_blockers.empty?

        {
          "tenant" => tenant,
          "group" => group,
          "target_bits" => TARGET_BITS,
          "status" => validation_blockers.empty? ? "ok" : "blocked",
          "blockers" => validation_blockers,
          "safe_metadata" => {
            "bank_connection" => bank_connection_summary,
            "protocol" => ebics_settings["protocol"],
            "rotation_strategy" => rotation_strategy,
            "active_keys" => active_key_summary,
            "pending_rotation" => pending_summary,
            "request" => request
          }.compact_blank
        }.compact
      rescue => e
        fail_safely!(e, stage: "validate_request_build")
      end

      def submit_pending!
        return readiness.merge("submitted" => false, "message" => "Pending key rotation already submitted") if pending_submitted?
        raise UnsupportedOperation, "Pending HCS submission has an uncertain outcome; run verify/promote or inspect bank state before retrying" if pending_submit_started?

        raise UnsupportedOperation, submission_blockers.to_sentence if submission_blockers.present?

        update_pending!(
          {
            "state" => "submitting",
            "submit_started_at" => now.iso8601
          },
          "submit_started_at" => now.iso8601)

        result = active_btf_client.key_change(target_key_store: pending_key_store, order_type: ROTATION_ORDER_TYPE)
        update_pending!(
          {
            "state" => "submitted",
            "submitted_at" => now.iso8601,
            "submit_result" => result.to_h
          },
          "submitted_at" => now.iso8601,
          "submit_result" => result.to_h)

        refreshed.readiness.merge("submitted" => true, "result" => result.to_h)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "submit")
      end

      def verify_pending!
        return readiness.merge("verified" => false, "message" => "Pending key rotation already verified") if pending_verified?

        raise UnsupportedOperation, verification_blockers.to_sentence if verification_blockers.present?

        result = verify_credentials!(pending_runtime_credentials)
        update_pending!(
          {
            "state" => "verified",
            "verified_at" => now.iso8601,
            "verification" => result
          },
          "verified_at" => now.iso8601,
          "verification" => result)

        refreshed.readiness.merge("verified" => true, "verification" => result)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "verify")
      end

      def promote_pending!
        raise UnsupportedOperation, promotion_blockers.to_sentence if promotion_blockers.present?

        previous = previous_credentials_payload(
          keys: ebics_credentials.fetch("keys"),
          reason: "promoted_pending_rotation")
        update_connection!(
          credentials: ebics_credentials
            .merge("keys" => pending_keys_json, PREVIOUS_CREDENTIAL_KEY => previous)
            .except(PENDING_CREDENTIAL_KEY),
          status: pending_status("rotated").merge(
            "promoted_at" => now.iso8601,
            "active_keys" => pending_summary.fetch("keys"),
            "previous_keys" => active_key_summary))

        refreshed.readiness.merge("promoted" => true)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "promote")
      end

      def perform!
        rotation = refreshed
        current_readiness = rotation.readiness
        return current_readiness.merge("performed" => false, "message" => "Participant keys are already at #{TARGET_BITS} bits") if at_target?(current_readiness)

        unless current_readiness["pending_rotation"].present?
          rotation.prepare_pending!
          rotation = refreshed
          current_readiness = rotation.readiness
        end

        unless submit_attempted?(current_readiness)
          rotation.submit_pending!
          rotation = refreshed
          current_readiness = rotation.readiness
        end

        unless verified?(current_readiness)
          rotation.verify_pending!
          rotation = refreshed
        end

        rotation.promote_pending!
      end



      def discard_pending!(reason: "manual_discard")
        return readiness.merge("discarded" => false, "message" => "No pending key rotation to discard") unless pending_keys_json.present?

        update_connection!(
          credentials: ebics_credentials.except(PENDING_CREDENTIAL_KEY),
          status: pending_status("rotation_failed").merge(
            "stage" => "discard_pending",
            "discarded_at" => now.iso8601,
            "reason" => reason,
            "error_message" => "Pending EBICS key rotation discarded; active keys kept"))

        refreshed.readiness.merge("discarded" => true)
      rescue UnsupportedOperation
        raise
      rescue => e
        fail_safely!(e, stage: "discard_pending")
      end

      private

      attr_reader :tenant, :connection, :now, :error_reporter, :key_generator, :btf_client_factory

      def state
        return "blocked" unless connection&.ebics?
        return recorded_state if recorded_state == "rotation_failed"
        return "blocked" if blockers.present?
        return "pending_rotation" if pending_keys_json.present?
        return "rotated" if recorded_state == "rotated" && already_at_target?
        return "already_at_target" if already_at_target?
        return "bank_limited_2048" if bank_limited_2048?
        return "candidate" if rotation_supported?
        return "rotated" if recorded_state == "rotated"

        "unknown"
      end

      def blockers
        @blockers ||= begin
          values = []
          values << "No active bank connection" unless connection
          values << "Active bank connection is not EBICS" if connection && !connection.ebics?
          values << "Active EBICS connection must use protocol H005" if connection&.ebics? && !h005_configured?
          values.concat(missing_credential_blockers)
          values.concat(key_blockers)
          values
        end
      end

      def prepare_blockers
        @prepare_blockers ||= begin
          values = blockers.dup
          values << "Bank is explicitly limited to 2048-bit participant keys" if bank_limited_2048?
          values << "Participant keys are already at #{TARGET_BITS} bits" if already_at_target?
          values
        end
      end

      def submission_blockers(require_submitted: false)
        values = blockers.dup
        values << "Bank is explicitly limited to 2048-bit participant keys" if bank_limited_2048?
        values << "Pending 4096-bit participant keys must be prepared first" unless pending_keys_json.present?
        values.concat(pending_key_blockers) if pending_keys_json.present?
        values << "HCS key-management order must be advertised or explicitly confirmed before live submission" unless rotation_supported?
        values << "Pending key rotation must be submitted first" if require_submitted && !pending_submitted?
        values
      end

      def verification_blockers
        values = submission_blockers(require_submitted: false)
        values << "Pending key rotation must be submitted first" unless pending_submitted? || pending_submit_started?
        values
      end

      def promotion_blockers
        values = verification_blockers
        values << "Pending key rotation must be verified before promotion" unless pending_verified?
        values
      end



      def missing_credential_blockers
        return [] unless connection&.ebics?

        missing = REQUIRED_CREDENTIALS.reject { |key| ebics_credentials[key].present? }
        missing.map { |key| "Missing EBICS credential: #{key}" }
      end

      def key_blockers
        return [] unless required_credentials_present?
        return [ active_key_error_message ] if active_key_error_message

        [].tap do |values|
          missing_participant_keys.each { |version| values << "Missing participant key #{version}" }
          missing_bank_key_suffixes.each { |suffix| values << "Missing bank public key #{suffix.delete_prefix(".")}" }
          values << "Participant keys must be at least 2048 bits" if participant_min_bits.to_i < 2048
          values << "Bank public keys must be at least 2048 bits" if bank_min_bits.to_i < 2048
        end
      end

      def pending_key_blockers
        return [ pending_key_error_message ] if pending_key_error_message

        [].tap do |values|
          PARTICIPANT_KEY_VERSIONS.each do |version|
            bits = pending_key_metadata.dig(version, "bits").to_i
            values << "Pending participant key #{version} must be #{TARGET_BITS} bits" if bits != TARGET_BITS
          end
        end
      end



      def required_credentials_present?
        connection&.ebics? && REQUIRED_CREDENTIALS.all? { |key| ebics_credentials[key].present? }
      end

      def h005_configured?
        ebics_settings["protocol"] == "H005"
      end

      def already_at_target?
        participant_min_bits.to_i >= TARGET_BITS
      end

      def bank_limited_2048?
        key_rotation_settings["bank_limited_2048"] == true
      end

      def rotation_supported?
        confirmed_rotation_strategy? || advertised_key_management_order_types.include?(ROTATION_ORDER_TYPE)
      end

      def confirmed_rotation_strategy?
        key_rotation_settings["confirmed"] == true && key_rotation_order_type == ROTATION_ORDER_TYPE
      end

      def rotation_strategy
        configured = key_rotation_settings.slice("confirmed", "order_type", "notes").compact_blank
        return { "status" => "bank_limited_2048" } if bank_limited_2048?
        return configured.merge("order_type" => ROTATION_ORDER_TYPE, "status" => "confirmed") if confirmed_rotation_strategy?
        return configured.merge("order_type" => ROTATION_ORDER_TYPE, "status" => "advertised") if advertised_key_management_order_types.include?(ROTATION_ORDER_TYPE)

        configured.merge(
          "status" => "unknown",
          "message" => "No HCS key-management order is advertised or explicitly confirmed")
      end

      def advertised_key_management_order_types
        @advertised_key_management_order_types ||= begin
          h005 = connection&.capabilities.to_h.deep_stringify_keys.fetch("h005") { {} }
          admin_orders = h005.fetch("admin_orders") { {} }
          order_types = admin_orders.values.flat_map do |result|
            Array(result["order_infos"]).filter_map { |info| info["admin_order_type"].presence } +
              Array(result["legacy_order_types"])
          end
          (order_types.map(&:to_s).map(&:upcase) & KEY_MANAGEMENT_ORDER_TYPES).sort
        end
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
        {
          "tenant" => tenant,
          "host_id" => ebics_credentials["host_id"],
          "endpoint_host" => endpoint_host
        }.compact_blank
      end

      def endpoint_host
        URI(ebics_credentials["url"]).host if ebics_credentials["url"].present?
      rescue URI::InvalidURIError
        nil
      end

      def active_key_summary
        return {} unless required_credentials_present?
        return { "error" => active_key_error_message } if active_key_error_message

        split_key_metadata(active_key_store.key_metadata).merge(
          "participant_versions" => active_key_summary_hash.fetch("participant_key_versions", []),
          "bank_versions" => active_key_summary_hash.fetch("bank_key_versions", []),
          "participant_min_bits" => participant_min_bits,
          "bank_min_bits" => bank_min_bits)
      end

      def pending_summary
        return unless pending_keys_json.present?

        {
          "state" => pending_credentials["state"] || "prepared",
          "target_bits" => pending_credentials["target_bits"],
          "created_at" => pending_credentials["created_at"],
          "submit_started_at" => pending_credentials["submit_started_at"],
          "submitted_at" => pending_credentials["submitted_at"],
          "verified_at" => pending_credentials["verified_at"],
          "submit_result" => pending_credentials["submit_result"],
          "verification" => pending_credentials["verification"],
          "keys" => pending_key_error_message ? { "error" => pending_key_error_message } : split_key_metadata(pending_key_metadata)
        }.compact_blank
      end

      def previous_summary
        return unless previous_keys_json.present?

        {
          "state" => previous_credentials["state"],
          "reason" => previous_credentials["reason"],
          "created_at" => previous_credentials["created_at"],
          "keys" => previous_key_error_message ? { "error" => previous_key_error_message } : split_key_metadata(previous_key_metadata)
        }.compact_blank
      end

      def split_key_metadata(metadata)
        {
          "participant" => metadata.reject { |name, _attributes| name.include?(".") },
          "bank" => metadata.select { |name, _attributes| name.include?(".") }
        }
      end

      def participant_min_bits
        active_key_summary_hash["participant_key_min_bits"]
      end

      def bank_min_bits
        active_key_summary_hash["bank_key_min_bits"]
      end

      def missing_participant_keys
        PARTICIPANT_KEY_VERSIONS - active_key_summary_hash.fetch("participant_key_versions", [])
      end

      def missing_bank_key_suffixes
        BANK_KEY_SUFFIXES.reject do |suffix|
          active_key_summary_hash.fetch("bank_key_versions", []).any? { |version| version.end_with?(suffix) }
        end
      end

      def active_key_summary_hash
        @active_key_summary_hash ||= active_key_store.key_summary
      rescue => e
        @active_key_error_message = "Unable to inspect active EBICS keys"
        report_unexpected(e, stage: "active_key_summary")
        {}
      end

      def active_key_store
        @active_key_store ||= KeyStore.new(ebics_credentials)
      end

      def active_key_error_message
        active_key_summary_hash
        @active_key_error_message
      end

      def pending_key_metadata
        @pending_key_metadata ||= pending_key_store.key_metadata
      rescue => e
        @pending_key_error_message = "Unable to inspect pending EBICS keys"
        report_unexpected(e, stage: "pending_key_summary")
        {}
      end

      def pending_key_store
        @pending_key_store ||= KeyStore.new(pending_runtime_credentials)
      end

      def pending_key_error_message
        pending_key_metadata
        @pending_key_error_message
      end

      def previous_key_metadata
        @previous_key_metadata ||= previous_key_store.key_metadata
      rescue => e
        @previous_key_error_message = "Unable to inspect previous EBICS keys"
        report_unexpected(e, stage: "previous_key_summary")
        {}
      end

      def previous_key_store
        @previous_key_store ||= KeyStore.new(credentials_with_keys(previous_keys_json))
      end

      def previous_key_error_message
        previous_key_metadata
        @previous_key_error_message
      end

      def generated_participant_keys
        PARTICIPANT_KEY_VERSIONS.index_with { key_generator.call }
      end

      def key_metadata_for(keys)
        keys.keys.sort.index_with do |name|
          key = Key.new(keys.fetch(name))
          {
            "role" => name.include?(".") ? "bank" : "participant",
            "bits" => key.bits,
            "public_digest" => key.public_digest
          }
        end
      end

      def build_request_metadata
        order_data_xml = active_btf_client.key_change_order_data_xml(target_key_store: pending_key_store, order_type: ROTATION_ORDER_TYPE)
        request_xml = active_btf_client.key_change_request_xml(target_key_store: pending_key_store, order_type: ROTATION_ORDER_TYPE)

        {
          "order_type" => ROTATION_ORDER_TYPE,
          "order_data" => xml_metadata(order_data_xml),
          "initialisation_request" => xml_metadata(request_xml),
          "sanitized" => true
        }
      end

      def xml_metadata(xml)
        doc = Nokogiri::XML(xml)
        {
          "root" => doc.root&.name,
          "bytes" => xml.bytesize,
          "sha256" => Digest::SHA256.hexdigest(xml)
        }
      end

      def verify_credentials!(credentials)
        result = btf_client_for(credentials).admin_order(VERIFICATION_ORDER_TYPE)
        {
          "order_type" => VERIFICATION_ORDER_TYPE,
          "receipt_sent" => result.receipt_sent,
          "verified_at" => now.iso8601
        }
      end

      def active_btf_client
        @active_btf_client ||= btf_client_for(ebics_credentials)
      end

      def btf_client_for(credentials)
        btf_client_factory.call(
          credentials,
          context: safe_context(stage: "key_rotation"))
      end

      def credentials_with_keys(keys)
        ebics_credentials.merge("keys" => keys)
      end

      def pending_runtime_credentials
        credentials_with_keys(pending_keys_json)
      end

      def previous_credentials_payload(keys:, reason:)
        {
          "state" => "available",
          "reason" => reason,
          "created_at" => now.iso8601,
          "keys" => keys
        }
      end

      def at_target?(readiness)
        readiness.dig("active_keys", "participant_min_bits").to_i >= TARGET_BITS
      end

      def submit_attempted?(readiness)
        readiness.dig("pending_rotation", "submitted_at").present? ||
          readiness.dig("pending_rotation", "submit_started_at").present?
      end

      def verified?(readiness)
        readiness.dig("pending_rotation", "verified_at").present?
      end

      def pending_submitted?
        pending_credentials["submitted_at"].present?
      end

      def pending_submit_started?
        pending_credentials["submit_started_at"].present?
      end

      def pending_verified?
        pending_credentials["verified_at"].present?
      end



      def recorded_status
        connection&.status_details.to_h.dig(STATUS_DETAILS_KEY)
      end

      def recorded_state
        recorded_status.to_h["state"]
      end

      def pending_status(state)
        sanitized_status(state).merge(
          "order_type" => ROTATION_ORDER_TYPE,
          "verification_order_type" => VERIFICATION_ORDER_TYPE)
      end

      def sanitized_status(state)
        {
          "state" => state,
          "target_bits" => TARGET_BITS,
          "host_id" => ebics_credentials["host_id"],
          "protocol" => ebics_settings["protocol"]
        }.compact_blank
      end

      def update_pending!(attributes, **status_attributes)
        update_connection!(
          credentials: ebics_credentials.merge(PENDING_CREDENTIAL_KEY => pending_credentials.merge(attributes)),
          status: pending_status("pending_rotation").merge(status_attributes))
      end

      def update_connection!(credentials:, status:)
        connection.update!(
          credentials: credentials,
          status_details: merged_status_details(status))
      end

      def merged_status_details(status)
        connection.status_details.to_h.deep_stringify_keys.merge(STATUS_DETAILS_KEY => status)
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
        raise UnsupportedOperation, "EBICS key rotation failed during #{stage}; inspect sanitized key_rotation status and error reporting context"
      end

      def record_failure!(error, stage:)
        return unless connection&.persisted?

        connection.update_columns(
          status_details: merged_status_details(sanitized_status("rotation_failed").merge(
            "stage" => stage,
            "failed_at" => Time.current.iso8601,
            "error_class" => error.class.name,
            "error_message" => "EBICS key rotation failed during #{stage}")),
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
        connection&.safe_context(operation_kind: "ebics_key_rotation", stage: stage) || {
          "tenant" => tenant,
          "operation_kind" => "ebics_key_rotation",
          "stage" => stage
        }
      end

      def ebics_credentials
        @ebics_credentials ||= connection&.credentials.to_h.deep_stringify_keys
      end

      def ebics_settings
        @ebics_settings ||= connection&.settings.to_h.deep_stringify_keys
      end

      def key_rotation_settings
        @key_rotation_settings ||= ebics_settings.fetch("key_rotation") { {} }.to_h.deep_stringify_keys
      end

      def key_rotation_order_type
        key_rotation_settings["order_type"].to_s.upcase.presence
      end

      def pending_credentials
        @pending_credentials ||= ebics_credentials.fetch(PENDING_CREDENTIAL_KEY) { {} }.to_h.deep_stringify_keys
      end

      def pending_keys_json
        pending_credentials["keys"]
      end

      def previous_credentials
        @previous_credentials ||= ebics_credentials.fetch(PREVIOUS_CREDENTIAL_KEY) { {} }.to_h.deep_stringify_keys
      end

      def previous_keys_json
        previous_credentials["keys"]
      end
    end
  end
end
