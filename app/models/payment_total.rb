class PaymentTotal
  include NumbersHelper
  include ActivitiesHelper
  include ActionView::Helpers::UrlHelper

  def self.all
    scopes = %i[paid missing]
    all = scopes.flatten.map { |scope| new(scope) }
    all << OpenStruct.new(price: all.sum(&:price))
  end

  attr_reader :scope

  def initialize(scope)
    @payments = Payment.current_year
    @invoices = Invoice.current_year.not_canceled
    @scope = scope
  end

  def title
    case scope
    when :paid
      txt = link_to_payments I18n.t("billing.scope.#{scope}")
      overpaid = @invoices.overpaid.sum("paid_amount - amount")
      if overpaid.positive?
        link = link_to_invoices(
          I18n.t("billing.scope.overpaid_amount", amount: cur(overpaid, format: "%n")),
          scope: :closed,
          q: {
            amount_gt: 0,
            balance_gt: 0
          })
        txt += " (#{link})".html_safe
      end
      txt
    when :missing
      txt = link_to_invoices I18n.t("billing.scope.#{scope}"), scope: :open
      if @invoices.with_overdue_notice.any?
        link = link_to_invoices(
          I18n.t("billing.scope.overdue_notices", count: @invoices.with_overdue_notice.count),
          scope: :open,
          q: { overdue_notices_count_gt: 0 })
        txt += " (#{link})".html_safe
      end
      txt
    end
  end

  def price
    @price ||=
      case scope
      when :paid
        @payments.sum(:amount)
      when :missing
        @invoices.open.sum("amount - paid_amount")
      end
  end

  private

  def link_to_invoices(title, scope:, q: {})
    fy = Current.fiscal_year
    url_helpers = Rails.application.routes.url_helpers
    link_to title, url_helpers.invoices_path(
      scope: scope,
      q: q.merge(during_year: fy.year))
  end

  def link_to_payments(title)
    fy = Current.fiscal_year
    url_helpers = Rails.application.routes.url_helpers
    link_to title, url_helpers.payments_path(
      scope: :all,
      q: { during_year: fy.year })
  end
end
