# frozen_string_literal: true

require "uri"

class BankConnection::EBICSSetup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :url, :string
  attribute :host_id, :string
  attribute :client_id, :string
  attribute :participant_id, :string
  attribute :confirmation, :boolean

  SUPPORTED_COUNTRY_CODES = %w[CH DE].freeze

  validates :url, :host_id, :client_id, :participant_id, presence: true
  validates :confirmation, acceptance: true
  validate :url_is_https

  def self.supported_country?(org = Current.org) = org.country_code.in?(SUPPORTED_COUNTRY_CODES)

  def self.model_name = ActiveModel::Name.new(self, nil, "EBICSSetup")

  def initialize(attributes = {})
    super(normalize(attributes))
  end

  def onboarding_attributes
    {
      url: url,
      host_id: host_id,
      client_id: client_id,
      participant_id: participant_id,
      name: host_id,
      target_bits: Billing::EBICS::Onboarding::TARGET_BITS
    }
  end

  def settings_for(org = Current.org)
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.payment_download(country_code: org.country_code)
        }
      }
    }.tap do |settings|
      if org.country_code == "DE" && org.sepa_creditor_identifier?
        settings["uploads"] = {
          "sepa_direct_debit" => {
            "mode" => "btf",
            "schema" => "pain.008.001.08",
            "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: nil)
          }
        }
      end
    end
  end

  def add_endpoint_check_error
    errors.add(:url, validation_message("endpoint"))
    errors.add(:base, validation_message("retry_or_contact"))
  end

  def add_host_id_check_error
    errors.add(:host_id, validation_message("host_id"))
    errors.add(:base, validation_message("retry_or_contact"))
  end

  def add_identifier_check_error
    errors.add(:client_id, validation_message("identifiers"))
    errors.add(:participant_id, validation_message("identifiers"))
    errors.add(:base, validation_message("retry_or_contact"))
  end

  private

  def validation_message(key)
    I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.#{key}")
  end

  def normalize(attributes)
    attributes.to_h.transform_values { |value| value.is_a?(String) ? value.strip : value }
  end

  def url_is_https
    return if url.blank?
    return if https_url?(url)

    errors.add(:url, :invalid)
  end

  def https_url?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?
  rescue URI::InvalidURIError
    false
  end
end
