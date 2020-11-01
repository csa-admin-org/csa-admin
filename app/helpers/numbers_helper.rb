module NumbersHelper
  include ActiveSupport::NumberHelper

  def currency_symbol
    case Current.acp.currency_code
    when 'EUR'; '€'
    else
      Current.acp.currency_code
    end
  end

  def cur(amount, unit: true, **options)
    options[:unit] = unit ? currency_symbol : ''
    options[:format] =
      case Current.acp.currency_code
      when 'EUR'; "%n %u"
      when 'CHF'; "%u %n"
      end
    number_to_currency(amount, **options)
  end
end
