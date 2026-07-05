# frozen_string_literal: true

class BankConnection < ApplicationRecord
  include HasState

  PROVIDERS = %w[ebics bas bunq mock]
  HEALTH_STATUSES = %w[unknown healthy warning errored]
  FILTERED = "[FILTERED]"
  SENSITIVE_CREDENTIAL_KEYS = %w[
    api_key
    contract_password
    installation_token
    keys
    passphrase
    password
    private_key
    secret
    token
  ]

  encrypts :credentials

  has_states :draft, :initializing, :waiting_for_bank, :ready, :disabled, :errored

  scope :active, -> { where(active: true) }

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :state, presence: true, inclusion: { in: STATES }
  validates :health_status, presence: true, inclusion: { in: HEALTH_STATUSES }
  validates :credentials, presence: true, if: :active?
  validate :json_columns_are_objects
  validate :only_one_active_connection, if: :active?

  def adapter
    case provider
    when "ebics"
      Billing::EBICS.new(credentials, settings: settings, bank_connection: self)
    when "bas"
      Billing::BAS.new(credentials)
    when "bunq"
      Billing::Bunq.new(credentials)
    when "mock"
      Billing::EBICSMock.new(credentials)
    end
  end

  def runtime_adapter
    ebics? ? adapter : RuntimeAdapter.new(self, adapter)
  end

  def sepa_direct_debit_upload?
    case provider
    when "ebics"
      operation_config = Billing::EBICS::OperationConfig.new(settings)
      operation_config.sepa_direct_debit_upload
      operation_config.sepa_direct_debit_upload_schema
      true
    when "mock"
      true
    else
      false
    end
  rescue Billing::EBICS::UnsupportedOperation
    false
  end

  def credential_keys
    credentials.to_h.keys.map(&:to_s).sort
  end

  def redacted_credentials
    redact(credentials.to_h)
  end

  def safe_summary
    {
      "provider" => provider,
      "name" => name,
      "active" => active?,
      "state" => state,
      "health_status" => health_status,
      "credential_keys" => credential_keys,
      "credentials" => redacted_credentials,
      "settings" => redact(settings.to_h),
      "capabilities" => redact(capabilities.to_h),
      "status_details" => redact(status_details.to_h)
    }
  end

  def ebics?
    provider == "ebics"
  end

  def ebics_key_summary
    return {} unless ebics?

    credentials = self.credentials.to_h.stringify_keys
    required_keys = %w[keys secret url host_id participant_id client_id]
    return {} unless required_keys.all? { |key| credentials[key].present? }

    Billing::EBICS::KeyStore.new(credentials).key_summary
  rescue => e
    {
      "error" => {
        "class" => e.class.name,
        "message" => "Unable to inspect EBICS keys"
      }
    }
  end

  def mark_import_attempted!(operation: nil)
    now = Time.current
    update_status!(
      last_import_attempted_at: now,
      status_details: merged_status_details("last_import",
        attempted_at: now.iso8601,
        operation: safe_operation(operation)))
  end

  def mark_import_succeeded!(operation: nil, files_count: nil, payments_count: nil)
    now = Time.current
    update_status!(
      health_status: "healthy",
      last_health_check_at: now,
      last_import_succeeded_at: now,
      last_error_class: nil,
      last_error_message: nil,
      status_details: merged_status_details("last_import",
        succeeded_at: now.iso8601,
        files_count: files_count,
        payments_count: payments_count,
        operation: safe_operation(operation)))
  end

  def mark_no_data!(operation: nil)
    now = Time.current
    update_status!(
      health_status: "healthy",
      last_health_check_at: now,
      last_no_data_at: now,
      last_error_class: nil,
      last_error_message: nil,
      status_details: merged_status_details("last_import",
        no_data_at: now.iso8601,
        files_count: 0,
        operation: safe_operation(operation)))
  end

  def mark_upload_attempted!(operation: nil, invoice_id: nil)
    now = Time.current
    update_status!(
      last_upload_attempted_at: now,
      status_details: merged_status_details("last_upload",
        attempted_at: now.iso8601,
        invoice_id: invoice_id,
        operation: safe_operation(operation)))
  end

  def mark_upload_succeeded!(operation: nil, invoice_id: nil, order_id: nil)
    now = Time.current
    update_status!(
      health_status: "healthy",
      last_health_check_at: now,
      last_upload_succeeded_at: now,
      last_error_class: nil,
      last_error_message: nil,
      status_details: merged_status_details("last_upload",
        succeeded_at: now.iso8601,
        invoice_id: invoice_id,
        order_id: order_id,
        operation: safe_operation(operation)))
  end

  def mark_capabilities_checked!(report:, status:, warnings: [])
    now = Time.current
    attributes = {
      health_status: status,
      last_health_check_at: now,
      capabilities: capabilities_summary(report),
      status_details: merged_status_details("last_capabilities_check",
        checked_at: now.iso8601,
        status: status,
        warnings: warnings)
    }

    if warnings.present?
      attributes.merge!(
        last_error_class: "UnexpectedEBICSCapability",
        last_error_message: warnings.first.to_s.truncate(500))
    else
      attributes.merge!(last_error_class: nil, last_error_message: nil)
    end

    update_status!(attributes)
  end

  def mark_error!(error, operation: nil, operation_kind: nil, **details)
    now = Time.current
    update_status!(
      health_status: "errored",
      last_health_check_at: now,
      last_error_class: error.class.name,
      last_error_message: error.message.to_s.truncate(500),
      status_details: merged_status_details("last_error",
        details.merge(
          occurred_at: now.iso8601,
          operation_kind: operation_kind,
          operation: safe_operation(operation))))
  end

  def safe_context(operation: nil, **attributes)
    Billing::EBICS::SafeContext.build(connection: self, operation: operation, **attributes)
  end

  private

  def update_status!(attributes)
    return unless persisted?

    update_columns(attributes.merge(updated_at: Time.current))
  rescue => e
    Rails.error.report(e, context: {
      bank_connection_id: id,
      provider: provider,
      bank: name,
      error: e.class.name,
      error_message: e.message
    })
    nil
  end

  def merged_status_details(key, attributes)
    current = status_details.to_h.deep_stringify_keys
    previous = current.fetch(key) { {} }.to_h
    current.merge(key => previous.merge(attributes.deep_stringify_keys).compact)
  end

  def safe_operation(operation)
    Billing::EBICS::SafeContext.operation(operation).presence || provider_operation(operation)
  end

  def provider_operation(operation)
    operation.to_h.deep_stringify_keys.slice("mode", "provider", "kind").compact_blank if operation.respond_to?(:to_h)
  end

  def capabilities_summary(report)
    report.to_h.deep_stringify_keys.slice("country_code", "h005").compact
  end

  def json_columns_are_objects
    %i[credentials settings capabilities status_details].each do |name|
      value = public_send(name)
      errors.add(name, "must be an object") unless value.is_a?(Hash)
    end
  end

  def only_one_active_connection
    return unless self.class.active.where.not(id: id).exists?

    errors.add(:active, "is already used by another bank connection")
  end

  def redact(value, key = nil)
    case value
    when Hash
      value.each_with_object({}) { |(child_key, child_value), redacted|
        redacted[child_key] = redact(child_value, child_key)
      }
    when Array
      value.map { |child_value| redact(child_value, key) }
    else
      sensitive_credential_key?(key) && value.present? ? FILTERED : value
    end
  end

  def sensitive_credential_key?(key)
    normalized_key = key.to_s.downcase
    SENSITIVE_CREDENTIAL_KEYS.any? { |sensitive_key|
      normalized_key == sensitive_key || normalized_key.end_with?("_#{sensitive_key}")
    }
  end
end
