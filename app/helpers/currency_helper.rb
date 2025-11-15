# frozen_string_literal: true

module CurrencyHelper
  def currency_codes_collection
    Current.org.currency_codes.map { |code| [ code.upcase, code ] }
  end

  def locale_currencies_collection
    Organization.local_currency_codes.map { |code|
      [ t("local_currency.#{code.downcase}.long"), code ]
    }
  end
end
