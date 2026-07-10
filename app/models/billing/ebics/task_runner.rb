# frozen_string_literal: true

module Billing
  class EBICS
    class TaskRunner
      TRUE_VALUES = %w[1 true yes].freeze

      def initialize(env: ENV)
        @env = env
      end

      def onboarding_status
        with_ebics_onboarding(&:status)
      end

      def onboarding_initialize
        require_confirmation!
        with_ebics_onboarding(required_connection: false, implicit_connection: false) { |onboarding|
          onboarding.initialize_connection!(
            url: required_env!("URL"),
            host_id: required_env!("HOST_ID"),
            client_id: required_ebics_identifier!("CLIENT_ID", legacy_key: "PARTNER_ID"),
            participant_id: required_ebics_identifier!("PARTICIPANT_ID", legacy_key: "USER_ID"),
            name: env["NAME"].presence,
            target_bits: (env["KEY_BITS"].presence || Onboarding::TARGET_BITS))
        }
      end

      def onboarding_letter
        with_ebics_onboarding { |onboarding|
          onboarding.write_letter!(
            output: onboarding_letter_output(onboarding),
            locale: env["LOCALE"].presence || I18n.locale)
        }
      end

      def onboarding_submit_ini
        require_confirmation!
        with_ebics_onboarding(&:submit_ini!)
      end

      def onboarding_submit_hia
        require_confirmation!
        with_ebics_onboarding(&:submit_hia!)
      end

      def onboarding_finalize
        require_confirmation!
        with_ebics_onboarding(&:finalize!)
      end

      def key_rotation_readiness
        results = []

        if tenant_name
          switch_tenant(tenant_name) do
            results << KeyRotation.new(tenant: tenant_name).readiness
          end
        else
          Tenant.switch_each do |tenant|
            next if Tenant.custom? && !env["TENANT"]
            next unless Current.org.active_bank_connection&.ebics?

            results << KeyRotation.new(tenant: tenant).readiness
          end
        end

        summarized(results, "state")
      end

      def key_rotation_prepare
        require_confirmation!
        with_key_rotation(&:prepare_pending!)
      end

      def key_rotation_validate
        with_key_rotation(&:request_build_validation)
      end

      def key_rotation_submit
        require_confirmation!
        with_key_rotation(&:submit_pending!)
      end

      def key_rotation_verify
        require_confirmation!
        with_key_rotation(&:verify_pending!)
      end

      def key_rotation_promote
        require_confirmation!
        with_key_rotation(&:promote_pending!)
      end

      def key_rotation_perform
        require_confirmation!
        with_key_rotation(&:perform!)
      end

      def key_rotation_discard_pending
        require_confirmation!
        reason = env["REASON"].presence || "manual_discard"
        with_key_rotation { |rotation| rotation.discard_pending!(reason: reason) }
      end

      def key_rotation_purge_previous
        require_confirmation!
        reason = env["REASON"].presence || "retention_policy"
        with_key_rotation { |rotation| rotation.purge_previous!(reason: reason) }
      end

      def key_rotation_batch_plan
        key_rotation_batch.plan
      end

      def key_rotation_batch_prepare
        require_batch_selection!
        require_confirmation!
        key_rotation_batch.prepare!
      end

      def key_rotation_batch_perform
        require_single_batch_perform_tenant!
        require_confirmation!
        key_rotation_batch.perform!
      end

      def readiness
        results = []

        if tenant_name
          switch_tenant(tenant_name) do
            results << ReadinessReport.new(tenant: tenant_name).to_h
          end
        else
          Tenant.switch_each do |tenant|
            next if Tenant.custom? && !env["TENANT"]

            results << ReadinessReport.new(tenant: tenant).to_h
          end
        end

        { results: results }
      end

      def monitor
        results = []

        if tenant_name
          switch_tenant(tenant_name) do
            results << monitor_capabilities_result(tenant_name, required: true)
          end
        else
          Tenant.switch_each do |tenant|
            result = monitor_capabilities_result(tenant)
            results << result if result
          end
        end

        summarized(results, "health_status")
      end

      def capabilities
        name = require_tenant_name!
        switch_tenant(name) do
          connection = Current.org.active_bank_connection
          raise UnsupportedOperation, "Tenant '#{name}' has no active EBICS bank connection" unless connection&.ebics?

          CapabilitiesReport.new(tenant: name, connection: connection).to_h
        end
      end

      def btf_download
        name = require_tenant_name!
        from = required_env!("FROM", suffix: " (YYYY-MM-DD)")
        to = required_env!("TO", suffix: " (YYYY-MM-DD)")
        acknowledge = truthy_env?("ACK")

        switch_tenant(name) do
          connection = Current.org.active_bank_connection
          raise UnsupportedOperation, "Tenant '#{name}' has no active EBICS bank connection" unless connection&.ebics?

          operation = OperationConfig.new(connection.settings).payment_download
          result = BtfClient
            .new(connection.credentials)
            .test_download(operation, from: from, to: to, acknowledge: acknowledge)

          {
            tenant: name,
            from: from,
            to: to,
            acknowledge_requested: acknowledge,
            operation: operation.btf,
            result: result.to_h
          }
        end
      end

      private

      attr_reader :env

      def with_ebics_onboarding(required_connection: true, implicit_connection: true)
        name = require_tenant_name!

        switch_tenant(name) do
          connection = implicit_connection ? ebics_onboarding_connection : explicit_ebics_onboarding_connection
          raise UnsupportedOperation, "Tenant '#{name}' has no EBICS onboarding bank connection" if required_connection && !connection

          yield Onboarding.new(connection: connection)
        end
      end

      def ebics_onboarding_connection
        explicit_ebics_onboarding_connection ||
          BankConnection.where(provider: "ebics", state: %w[draft initializing waiting_for_bank errored]).order(id: :desc).first ||
          ebics_active_bank_connection
      end

      def explicit_ebics_onboarding_connection
        id = env["BANK_CONNECTION_ID"].presence || env["CONNECTION_ID"].presence
        return unless id

        BankConnection.find(id).tap do |connection|
          raise UnsupportedOperation, "Bank connection ##{id} is not EBICS" unless connection.ebics?
        end
      end

      def ebics_active_bank_connection
        Current.org.active_bank_connection if Current.org.active_bank_connection&.ebics?
      end

      def onboarding_letter_output(onboarding)
        env["OUTPUT"].presence || Rails.root.join(
          "tmp",
          "ebics-initialization-letter-#{Tenant.current}-#{onboarding.connection.id}.pdf").to_s
      end

      def with_key_rotation
        name = require_tenant_name!

        switch_tenant(name) do
          connection = Current.org.active_bank_connection
          raise UnsupportedOperation, "Tenant '#{name}' has no active EBICS bank connection" unless connection&.ebics?

          yield KeyRotation.new(tenant: name, connection: connection)
        end
      end

      def key_rotation_batch
        KeyRotationBatch.new(
          tenant_names: key_rotation_batch_tenant_names,
          provider: env["PROVIDER"].presence,
          all: truthy_env?("ALL"),
          verify_payments: truthy_env?("VERIFY_PAYMENTS"))
      end

      def key_rotation_batch_tenant_names
        (env["TENANTS"].presence || env["TENANT"].presence || env["TENANT_NAME"].presence)
          .to_s
          .split(/[,\s]+/)
          .compact_blank
      end

      def require_batch_selection!
        return if key_rotation_batch_tenant_names.present?
        return if env["PROVIDER"].present?
        return if truthy_env?("ALL")

        raise UnsupportedOperation, "Set TENANTS, PROVIDER, or ALL=true"
      end

      def require_single_batch_perform_tenant!
        raise UnsupportedOperation, "Use TENANT, not TENANTS, for live batch perform" if env["TENANTS"].present?
        raise UnsupportedOperation, "PROVIDER is plan/prepare only; set one TENANT for live batch perform" if env["PROVIDER"].present?
        raise UnsupportedOperation, "ALL=true is not supported for live batch perform; set one TENANT" if truthy_env?("ALL")
        raise UnsupportedOperation, "Set exactly one TENANT for live batch perform" unless key_rotation_batch_tenant_names.one?
      end

      def monitor_capabilities_result(tenant, required: false)
        connection = Current.org.active_bank_connection
        raise UnsupportedOperation, "Tenant '#{tenant}' has no active EBICS bank connection" if required && !connection&.ebics?
        return unless connection&.ebics?

        CapabilitiesMonitor.new(connection: connection).check!
        connection.reload

        {
          "tenant" => tenant,
          "bank_connection_id" => connection.id,
          "bank" => connection.name,
          "health_status" => connection.health_status,
          "warnings" => connection.status_details.dig("last_capabilities_check", "warnings") || [],
          "last_health_check_at" => connection.last_health_check_at&.iso8601
        }
      end

      def tenant_name
        env["TENANT"].presence || env["TENANT_NAME"].presence
      end

      def require_tenant_name!
        tenant_name.presence || raise(UnsupportedOperation, "TENANT is required")
      end

      def switch_tenant(name)
        raise UnsupportedOperation, "Tenant '#{name}' does not exist" unless Tenant.exists?(name)

        result = nil
        Tenant.switch(name) { result = yield }
        result
      end

      def required_env!(key, suffix: nil)
        env[key].presence || raise(UnsupportedOperation, "#{key} is required#{suffix}")
      end

      def required_ebics_identifier!(key, legacy_key:)
        env[key].presence || env[legacy_key].presence || raise(UnsupportedOperation, "#{key} is required")
      end

      def require_confirmation!
        raise UnsupportedOperation, "CONFIRM=true is required" unless truthy_env?("CONFIRM")
      end

      def truthy_env?(key)
        env[key].in?(TRUE_VALUES)
      end

      def summarized(results, key)
        {
          summary: results.map { |result| result.fetch(key) }.tally,
          results: results
        }
      end
    end
  end
end
