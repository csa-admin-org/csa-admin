# frozen_string_literal: true

module Billing
  class EBICS
    class KeyRotationBatch
      READY_STATES = %w[candidate pending_rotation].freeze
      NOOP_STATES = %w[already_at_target rotated].freeze
      TRUE_VALUES = %w[1 true yes].freeze

      def initialize(tenant_names: nil, provider: nil, all: false, verify_payments: false, now: Time.current, rotation_factory: ->(tenant:, connection:) { KeyRotation.new(tenant: tenant, connection: connection) }, payment_processor: Billing::PaymentsProcessor)
        @tenant_names = Array(tenant_names).compact_blank
        @provider = provider.presence
        @all = all
        @verify_payments = verify_payments
        @now = now
        @rotation_factory = rotation_factory
        @payment_processor = payment_processor
      end

      def plan
        report("plan", collect(action: "plan") { |tenant, rotation, connection|
          readiness = rotation.readiness
          readiness_result(tenant, connection, readiness, status_for(readiness))
        })
      end

      def prepare!
        report("prepare", collect(action: "prepare", stop_on_error: true) { |tenant, rotation, connection|
          readiness = rotation.readiness

          if noop?(readiness)
            readiness_result(tenant, connection, readiness, "noop", message: "Participant keys are already at target")
          elsif readiness.fetch("state") == "pending_rotation"
            readiness_result(tenant, connection, readiness, "noop", message: "Pending key rotation already exists")
          elsif ready?(readiness)
            readiness_result(tenant, connection, rotation.prepare_pending!, "prepared")
          else
            readiness_result(tenant, connection, readiness, "skipped", message: "Tenant is not eligible for key rotation")
          end
        })
      end

      def perform!
        report("perform", collect(action: "perform", stop_on_error: true) { |tenant, rotation, connection|
          readiness = rotation.readiness

          if noop?(readiness)
            readiness_result(tenant, connection, readiness, "noop", message: "Participant keys are already at target")
          elsif ready?(readiness)
            if readiness.fetch("state") == "candidate"
              rotation.prepare_pending!
              rotation = rotation_for(tenant, connection)
            end

            validation = rotation.request_build_validation
            raise UnsupportedOperation, validation.fetch("blockers").to_sentence unless validation.fetch("status") == "ok"

            result = readiness_result(tenant, connection, rotation.perform!, "rotated")
            verify_payments!(result) if verify_payments
            result
          else
            readiness_result(tenant, connection, readiness, "skipped", message: "Tenant is not eligible for key rotation")
          end
        })
      end

      private

      attr_reader :tenant_names, :provider, :all, :verify_payments, :now, :rotation_factory, :payment_processor

      def collect(action:, stop_on_error: false)
        validate_tenants!
        results = []

        selected_tenant_names.each do |tenant|
          result = nil
          Tenant.switch(tenant) do
            result = collect_tenant(tenant, action) { |rotation, connection|
              yield tenant, rotation, connection
            }
          end

          next unless result

          results << result
          break if stop_on_error && result.fetch("status") == "error"
        end

        results
      end

      def collect_tenant(tenant, action)
        connection = Current.org.active_bank_connection
        return no_ebics_result(tenant, connection) unless connection&.ebics?
        return provider_mismatch_result(tenant, connection) if provider && !provider_matches?(connection)

        yield rotation_for(tenant, connection), connection
      rescue => error
        error_result(tenant, connection, action, error)
      end

      def rotation_for(tenant, connection)
        rotation_factory.call(tenant: tenant, connection: connection.reload)
      end

      def selected_tenant_names
        explicit_tenants? ? tenant_names : Tenant.all
      end

      def explicit_tenants?
        tenant_names.present?
      end

      def validate_tenants!
        unknown = tenant_names.reject { |tenant| Tenant.exists?(tenant) }
        raise UnsupportedOperation, "Unknown tenant#{'s' if unknown.many?}: #{unknown.to_sentence}" if unknown.any?
      end

      def provider_matches?(connection)
        provider_filter = provider.downcase
        provider_candidates(connection).any? { |candidate| candidate.to_s.downcase == provider_filter }
      end

      def provider_candidates(connection)
        credentials = connection.credentials.to_h.deep_stringify_keys
        [ connection.provider, connection.name, credentials["host_id"] ].compact_blank
      end

      def no_ebics_result(tenant, connection)
        return if !explicit_tenants? && !all

        selection_result(tenant, connection, "skipped", "Tenant has no active EBICS bank connection")
      end

      def provider_mismatch_result(tenant, connection)
        return if !explicit_tenants? && !all

        selection_result(tenant, connection, "skipped", "Active EBICS bank connection does not match PROVIDER=#{provider}")
      end

      def selection_result(tenant, connection, status, message)
        {
          "tenant" => tenant,
          "status" => status,
          "provider" => connection&.provider,
          "bank" => connection&.name,
          "message" => message
        }.compact
      end

      def readiness_result(tenant, connection, readiness, status, message: nil)
        {
          "tenant" => tenant,
          "status" => status,
          "state" => readiness["state"],
          "message" => message,
          "provider" => connection.provider,
          "bank" => connection.name,
          "host_id" => readiness.dig("group", "host_id"),
          "endpoint_host" => readiness.dig("group", "endpoint_host"),
          "protocol" => readiness["protocol"],
          "target_bits" => readiness["target_bits"],
          "participant_min_bits" => readiness.dig("active_keys", "participant_min_bits"),
          "bank_min_bits" => readiness.dig("active_keys", "bank_min_bits"),
          "rotation_strategy" => readiness["rotation_strategy"],
          "pending_state" => readiness.dig("pending_rotation", "state"),
          "previous_state" => readiness.dig("previous_rotation", "state"),
          "blockers" => readiness["blockers"]
        }.compact_blank
      end

      def error_result(tenant, connection, action, error)
        {
          "tenant" => tenant,
          "status" => "error",
          "provider" => connection&.provider,
          "bank" => connection&.name,
          "error_class" => error.class.name,
          "error_message" => safe_error_message(action, error)
        }.compact
      end

      def safe_error_message(action, error)
        return error.message if error.is_a?(UnsupportedOperation)

        "EBICS key rotation batch failed during #{action}"
      end

      def ready?(readiness)
        READY_STATES.include?(readiness.fetch("state"))
      end

      def noop?(readiness)
        NOOP_STATES.include?(readiness.fetch("state"))
      end

      def status_for(readiness)
        return "ready" if ready?(readiness)
        return "noop" if noop?(readiness)

        "skipped"
      end

      def verify_payments!(result)
        payment_processor.retrieve_and_process!
        result["payment_verification"] = { "status" => "ok" }
      rescue => error
        result["status"] = "error"
        result["payment_verification"] = {
          "status" => "error",
          "error_class" => error.class.name,
          "error_message" => "Payment verification failed after EBICS key rotation"
        }
      end

      def report(action, results)
        {
          "action" => action,
          "checked_at" => now.iso8601,
          "filters" => {
            "tenants" => tenant_names.presence,
            "provider" => provider,
            "all" => all,
            "verify_payments" => verify_payments
          }.compact_blank,
          "summary" => results.map { |result| result.fetch("status") }.tally,
          "results" => results
        }
      end
    end
  end
end
