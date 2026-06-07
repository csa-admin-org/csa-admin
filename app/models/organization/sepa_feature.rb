# frozen_string_literal: true

require "sepa_king"

module Organization::SEPAFeature
  extend ActiveSupport::Concern

  SEPA_COUNTRY_CODES = %w[DE NL].freeze

  included do
    validates :sepa_creditor_identifier, presence: true, if: -> { feature?("sepa") }
    validates_with SEPA::CreditorIdentifierValidator,
      field_name: :sepa_creditor_identifier,
      if: :sepa_creditor_identifier?

    validate :sepa_country_must_be_supported, if: -> { feature?("sepa") }
  end

  def sepa?
    feature?("sepa")
  end

  def sepa_country?
    country_code.in?(SEPA_COUNTRY_CODES)
  end
  alias_method :sepa_supported?, :sepa_country?

  def sepa_configured?
    sepa? && sepa_creditor_identifier?
  end

  private

  def sepa_country_must_be_supported
    return if sepa_country?

    errors.add(:country_code, :inclusion)
  end
end
