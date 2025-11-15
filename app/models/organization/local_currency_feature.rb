# frozen_string_literal: true

module Organization::LocalCurrencyFeature
  extend ActiveSupport::Concern

  LOCAL_CURRENCIES = [
    LocalCurrency::Radis::CODE
  ]

  included do
    encrypts :local_currency_secret

    with_options if: -> { feature?("local_currency") } do
      validates :local_currency_code,
        presence: true,
        inclusion: { in: LOCAL_CURRENCIES }
      validates :local_currency_identifier, presence: true
      validates :local_currency_wallet, presence: true
      validates :local_currency_secret, presence: true
    end
  end

  class_methods do
    def local_currency_codes = LOCAL_CURRENCIES
  end

  def currency_codes
    codes = [ currency_code ]
    codes << local_currency_code if feature?("local_currency")
    codes
  end

  def local_currency_wallet=(wallet)
    super wallet&.gsub(/^comchain:|0x/, "")
  end

  def local_currency_secret=(value)
    return if value&.chars&.uniq == [ "*" ]

    super
  end
end
