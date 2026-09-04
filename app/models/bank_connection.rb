# frozen_string_literal: true

class BankConnection < ApplicationRecord
  include HasState
  include BAS

  PROVIDERS = %w[ebics bas bunq mock]
  HEALTH_STATUSES = %w[unknown healthy warning errored]
  SUPPORTED_EBICS_SEPA_DIRECT_DEBIT_SCHEMAS = %w[pain.008.001.08].freeze
  EBICS_BTF_SERVICE_KEYS = %w[service_name scope service_option container message_name version].freeze
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
  validate :active_connection_is_ready
  validate :active_ebics_configuration, if: :active_ebics?
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
      operation = operation_config.sepa_direct_debit_upload
      operation_config.sepa_direct_debit_upload_schema
      ebics_sepa_direct_debit_upload_advertised?(operation)
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

    Billing::EBICS::KeyMetadata.inspectable_key_summary(credentials)
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
    error_summary = Billing::EBICS::SafeContext.error_summary(error, operation_kind: operation_kind)
    update_status!(
      health_status: "errored",
      last_health_check_at: now,
      last_error_class: error_summary.fetch("error_class"),
      last_error_message: error_summary.fetch("error_message"),
      status_details: merged_status_details("last_error",
        Billing::EBICS::SafeContext.sanitize(details).merge(
          error_summary.except("error_message"),
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
      error_class: e.class.name
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
      errors.add(name, :must_be_an_object) unless value.is_a?(Hash)
    end
  end

  def active_connection_is_ready
    errors.add(:state, :must_be_ready_when_active) if active? && !ready?
  end

  def active_ebics_configuration
    validate_ebics_protocol
    validate_ebics_credentials
    validate_payment_download_configuration
    validate_sepa_direct_debit_upload_configuration
  end

  def active_ebics?
    active? && ebics?
  end

  def validate_ebics_protocol
    errors.add(:settings, :must_use_h005_when_active) unless ebics_settings["protocol"] == "H005"
  end

  def validate_ebics_credentials
    return unless credentials.is_a?(Hash)

    attributes = ebics_credentials
    missing_credentials = Billing::EBICS::KeyMetadata::REQUIRED_CREDENTIALS.reject { |key| attributes[key].present? }
    if missing_credentials.present?
      errors.add(:credentials, :missing_required_ebics_values, values: missing_credentials.to_sentence)
      return
    end

    key_store = Billing::EBICS::KeyStore.new(attributes)
    key_summary = key_store.key_summary
    validate_participant_key_material(key_store, key_summary)
    validate_bank_key_material(key_store, key_summary)
  rescue
    errors.add(:credentials, :must_contain_valid_ebics_key_material)
  end

  def validate_participant_key_material(key_store, key_summary)
    unless Billing::EBICS::KeyMetadata.participant_keys_present?(key_summary)
      errors.add(:credentials, :must_contain_participant_keys)
      return
    end

    participant_keys = Billing::EBICS::KeyMetadata::PARTICIPANT_KEY_VERSIONS.map { |version| key_store.keys.fetch(version) }
    unless participant_keys.all? { |key| key.key.private? }
      errors.add(:credentials, :must_contain_private_participant_keys)
    end
    if key_summary["participant_key_min_bits"].to_i < 2048
      errors.add(:credentials, :participant_keys_too_short)
    end
  end

  def validate_bank_key_material(key_store, key_summary)
    required_versions = Billing::EBICS::KeyMetadata::BANK_KEY_SUFFIXES.map { |suffix| "#{ebics_credentials.fetch("host_id").upcase}#{suffix}" }
    unless required_versions.all? { |version| key_store.keys.key?(version) }
      errors.add(:credentials, :must_contain_configured_host_bank_keys)
      return
    end

    bank_keys = required_versions.map { |version| key_store.keys.fetch(version) }
    unless bank_keys.none? { |key| key.key.private? }
      errors.add(:credentials, :must_contain_public_bank_keys)
    end
    if key_summary["bank_key_min_bits"].to_i < 2048
      errors.add(:credentials, :bank_keys_too_short)
    end
  end

  def validate_payment_download_configuration
    validate_btf_operation(
      ebics_settings.dig("downloads", "payments"),
      order_type: "BTD",
      required_fields: %w[service_name scope container message_name],
      message: :incomplete_btd_payment_download)
  end

  def validate_sepa_direct_debit_upload_configuration
    uploads = ebics_settings["uploads"]
    return if uploads.blank? && !sepa_direct_debit_upload_required?

    unless uploads.is_a?(Hash)
      errors.add(:settings, :incomplete_btu_sepa_direct_debit_upload)
      return
    end

    upload = uploads["sepa_direct_debit"]
    return if upload.blank? && !sepa_direct_debit_upload_required?
    return if upload.to_h["mode"] != "btf" && !sepa_direct_debit_upload_required?

    return unless validate_btf_operation(
      upload,
      order_type: "BTU",
      required_fields: %w[service_name service_option message_name],
      message: :incomplete_btu_sepa_direct_debit_upload)

    btf = upload.fetch("btf").deep_stringify_keys
    if btf.values_at("scope", "container").any?(&:present?)
      errors.add(:settings, :must_use_non_container_btu_sepa_direct_debit_upload)
      return
    end

    unless btf["message_name"] == "pain.008"
      errors.add(:settings, :must_use_pain_008_for_btu)
      return
    end

    version = btf["version"].presence
    schema = upload["schema"].presence
    if version
      expected_schema = "pain.008.001.#{version.to_s.rjust(2, "0")}"
      unless expected_schema.in?(SUPPORTED_EBICS_SEPA_DIRECT_DEBIT_SCHEMAS)
        errors.add(:settings, :must_use_supported_pain_008_schema)
      end
      if schema.present? && schema != expected_schema
        errors.add(:settings, :pain_008_schema_must_match_btu_version)
      end
    elsif !schema.in?(SUPPORTED_EBICS_SEPA_DIRECT_DEBIT_SCHEMAS)
      errors.add(:settings, :must_use_explicit_pain_008_schema_without_btu_version)
    end
  end

  def sepa_direct_debit_upload_required?
    Current.org.sepa_configured?
  rescue
    false
  end

  def validate_btf_operation(operation, order_type:, required_fields:, message:)
    attributes = operation.is_a?(Hash) ? operation.deep_stringify_keys : {}
    btf = attributes["btf"].is_a?(Hash) ? attributes["btf"].deep_stringify_keys : {}
    complete = attributes["mode"] == "btf" &&
      btf["order_type"] == order_type &&
      required_fields.all? { |field| btf[field].present? }

    errors.add(:settings, message) unless complete
    complete
  end

  def ebics_sepa_direct_debit_upload_advertised?(operation)
    configured = operation.btf.slice(*EBICS_BTF_SERVICE_KEYS).compact_blank
    uploads = capabilities.to_h.deep_stringify_keys.dig("h005", "htd_btf_uploads")

    Array(uploads).any? do |info|
      info = info.to_h.deep_stringify_keys
      advertised = info["service"].to_h.slice(*EBICS_BTF_SERVICE_KEYS).compact_blank
      info["admin_order_type"] == "BTU" && advertised == configured
    end
  end

  def ebics_credentials
    credentials.to_h.deep_stringify_keys
  end

  def ebics_settings
    settings.is_a?(Hash) ? settings.deep_stringify_keys : {}
  end

  def only_one_active_connection
    return unless self.class.active.where.not(id: id).exists?

    errors.add(:active, :already_used_by_another_bank_connection)
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
