module GroupBuying
  class OrderTotal
    include NumbersHelper
    include ActionView::Helpers::UrlHelper

    def self.all(delivery)
      scopes = %i[open closed]
      all = scopes.flatten.map { |scope| new(delivery, scope) }
      all << OpenStruct.new(price: all.sum(&:price))
    end

    attr_reader :scope

    def initialize(delivery, scope)
      @delivery = delivery
      @orders = delivery.orders.joins(:invoice).send(scope)
      @scope = scope
    end

    def title
      link_to_orders I18n.t("states.group_buying/order.#{scope}").capitalize
    end

    def count
      link_to_orders @orders.count
    end

    def price
      @orders.sum('invoices.amount')
    end

    private

    def link_to_orders(title)
      url_helpers = Rails.application.routes.url_helpers
      link_to(
        title,
        url_helpers.group_buying_orders_path(
          scope: scope,
          q: { delivery_id_eq: @delivery.id }))
    end
  end
end
