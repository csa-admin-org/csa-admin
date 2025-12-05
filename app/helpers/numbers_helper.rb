# frozen_string_literal: true

module NumbersHelper
  include ActiveSupport::NumberHelper

  def currency_symbol(currency_code = nil)
    currency_code ||= Current.org.currency_code
    case currency_code
    when "EUR"; "€"
    else
      currency_code
    end
  end

  def ccur(object, attr, **options)
    cur(object.public_send(attr), currency_code: object.currency_code, **options)
  end

  def cur(amount, unit: true, currency_code: nil, **options)
    options[:unit] = unit ? currency_symbol(currency_code) : ""
    options[:format] ||=
      case Current.org.currency_code
      when "EUR"; "%n %u"
      when "CHF"; "%u %n"
      else
       "%u %n"
      end
    options[:negative_format] ||=
      if unit
        case Current.org.currency_code
        when "EUR"; "-%n %u"
        when "CHF"; "%u -%n"
        else
          "%u -%n"
        end
      else
        "-%n"
      end
    number_to_currency(amount, **options)
  end

  def kg(amount)
    number = number_to_rounded(amount,
      precision: 2,
      strip_insignificant_zeros: true)
    "#{sprintf("%.1f", number)} kg"
  end

  def _number_to_percentage(number, **options)
    txt = number_to_percentage(number, **options)
    if number.positive?
      "+#{txt}"
    else
      txt
    end
  end

  def prefer_integer(number)
    return unless number
    return if number&.zero?

    number == number.to_i ? number.to_i : number
  end
end
