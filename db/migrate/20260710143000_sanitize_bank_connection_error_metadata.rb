# frozen_string_literal: true

require "digest"

class SanitizeBankConnectionErrorMetadata < ActiveRecord::Migration[8.1]
  PROVIDER_TEXT_KEYS = %w[
    body
    description
    detail
    error_message
    finalization_report_text
    message
    provider_error
    reason
    report_text
    response_body
    response_text
  ].freeze
  PROVIDER_TEXT_KEY_SUFFIXES = %w[
    _body
    _description
    _detail
    _error_message
    _provider_error
    _reason
    _report_text
    _response_text
  ].freeze

  class MigrationBankConnection < ActiveRecord::Base
    self.table_name = "bank_connections"
  end

  def up
    MigrationBankConnection.reset_column_information
    MigrationBankConnection.find_each do |connection|
      attributes = { status_details: sanitize(connection.status_details.to_h) }
      if connection.last_error_message.present?
        attributes[:last_error_message] = "Bank connection operation failed"
      end
      connection.update_columns(attributes)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "raw provider error text is intentionally not recoverable"
  end

  private

  def sanitize(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, item), sanitized|
        key = key.to_s
        if provider_text_key?(key) && !item.is_a?(Hash) && !item.is_a?(Array)
          sanitized["#{key}_length"] = item.to_s.bytesize
          sanitized["#{key}_sha256"] = Digest::SHA256.hexdigest(item.to_s)
        else
          sanitized[key] = sanitize(item)
        end
      end
    when Array
      value.map { |item| sanitize(item) }
    else
      value
    end
  end

  def provider_text_key?(key)
    PROVIDER_TEXT_KEYS.include?(key) || PROVIDER_TEXT_KEY_SUFFIXES.any? { |suffix| key.end_with?(suffix) }
  end
end
