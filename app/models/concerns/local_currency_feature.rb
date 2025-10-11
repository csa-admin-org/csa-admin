# frozen_string_literal: true

module LocalCurrencyFeature
  extend ActiveSupport::Concern

  LOCAL_CURRENCIES = %w[RAD] # ComChain Radis

  included do
    with_options if: -> { feature?("local_currency") } do
      validates :local_currency_code,
        presence: true,
        inclusion: { in: LOCAL_CURRENCIES }
      validates :local_currency_identifier, presence: true
      validates :local_currency_wallet, presence: true
    end
  end

  class_methods do
    def local_currency_codes
      LOCAL_CURRENCIES
    end
  end

  def currency_codes
    codes = [ currency_code ]
    codes << local_currency_code if feature?("local_currency")
    codes
  end
end
