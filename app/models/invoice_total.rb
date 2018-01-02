class InvoiceTotal
  SCOPES = %i[amount balance missing_amount]

  def self.all(billing_totals_price)
    SCOPES.map { |scope| new(scope, billing_totals_price) }
  end

  attr_reader :scope

  def initialize(scope, billing_totals_price)
    @invoices = Invoice.current_year.not_canceled
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
      when :amount
        @invoices.sum(:amount)
      when :balance
        @invoices.sum(:balance)
      when :missing_amount
        @billing_totals_price - @invoices.sum(:amount)
      end
  end
end
