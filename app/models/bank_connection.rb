# frozen_string_literal: true

class BankConnection < ApplicationRecord
  include HasState

  PROVIDERS = Organization::Billing::BANK_CONNECTION_TYPES
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
      Billing::EBICS.new(credentials)
    when "bas"
      Billing::BAS.new(credentials)
    when "bunq"
      Billing::Bunq.new(credentials)
    when "mock"
      Billing::EBICSMock.new(credentials)
    end
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

    require "epics"
    client = Epics::Client.new(
      credentials.fetch("keys"),
      credentials.fetch("secret"),
      credentials.fetch("url"),
      credentials.fetch("host_id"),
      credentials.fetch("participant_id"),
      credentials.fetch("client_id"))

    key_bits = client.keys.transform_values { |key| key.key.n.to_i.bit_length }
    participant_keys = key_bits.reject { |name, _bits| name.include?(".") }
    bank_keys = key_bits.select { |name, _bits| name.include?(".") }

    {
      "key_names" => key_bits.keys.sort,
      "key_bits" => key_bits.sort.to_h,
      "participant_key_min_bits" => participant_keys.values.min,
      "bank_key_min_bits" => bank_keys.values.min,
      "participant_key_versions" => participant_keys.keys.sort,
      "bank_key_versions" => bank_keys.keys.sort
    }
  rescue => e
    {
      "error" => {
        "class" => e.class.name,
        "message" => "Unable to inspect EBICS keys"
      }
    }
  end

  private

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
