class InvoiceTotal
  SCOPES = %i[amount balance missing_amount]

  def self.all(billing_totals_price)
    cache_key = [
      name,
      Invoice.maximum(:updated_at),
      billing_totals_price
    ]
    Rails.cache.fetch cache_key do
      invoices = Invoice.current_year.to_a
      SCOPES.map { |scope| new(invoices, billing_totals_price, scope) }
    end
  end

  attr_reader :scope

  def initialize(invoices, billing_totals_price, scope)
    @invoices = invoices
    @billing_totals_price = billing_totals_price
    @scope = scope
    # eager load for the cache
    price
  end

  def title
    I18n.t("invoice.scope.#{scope}")
  end

  def price
    @price ||=
      case scope
      when :missing_amount
        @billing_totals_price - @invoices.sum(&:amount)
      else
        @invoices.sum { |i| i.send(scope) }
      end
  end
end
