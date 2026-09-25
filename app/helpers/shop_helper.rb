# frozen_string_literal: true

module ShopHelper
  def show_shop_menu?
    return unless feature?("shop")
    return unless current_shop_delivery || shop_special_deliveries.any?

    !Current.org.shop_admin_only || current_session.admin_originated?
  end

  def smart_shop_orders_path
    if delivery = smart_shop_delivery
      shop_orders_path(q: { _delivery_gid_eq: delivery.gid })
    else
      shop_orders_path
    end
  end

  def live_stock(variant, order)
    return unless variant.stock

    variant_order = order.items.find { |i| i.product_variant_id == variant.id }

    stock = variant.stock
    stock -= variant_order.quantity if variant_order
    stock
  end

  def display_variants(arbre, product)
    arbre.ul do
      product.variants.each do |variant|
        arbre.li class: ("unavailable" unless variant.available?) do
          arbre.span do
            link_to edit_shop_product_path(product, anchor: :variants) do
              parts = [ variant.name ]
              parts << cur(variant.price)
              parts << "<b>#{variant.stock}x</b>" unless variant.stock.nil?
              parts.join(", ").html_safe
            end
          end
        end
      end
    end
  end

  def products_collection
    Shop::Product.kept.includes(:variants).order_by_name.map do |product|
      [ product.name, product.id, disabled: product.variants.all?(&:out_of_stock?) ]
    end
  end

  def shop_member_percentages_collection
    Current.org[:shop_member_percentages].reverse.map do |percentage|
      text =
        if percentage.positive?
          t("shop.percentage.positive", percentage: percentage)
        else
          t("shop.percentage.negative", percentage: percentage)
        end
      [ text, percentage ]
    end
  end

  def shop_member_percentages_label(order)
    if order.amount_percentage.in?(Current.org[:shop_member_percentages])
      return t("shop.percentages_title.remove")
    end

    if Current.org[:shop_member_percentages].all?(&:positive?)
      t("shop.percentages_title.positive")
    elsif Current.org[:shop_member_percentages].all?(&:negative?)
      t("shop.percentages_title.negative")
    else
      t("shop.percentages_title.mixed")
    end
  end

  def shop_deliveries_collection(used: false)
    deliveries =
      if used
        Delivery.joins(:shop_orders).distinct +
          Shop::SpecialDelivery.joins(:shop_orders).distinct +
          [ selected_shop_delivery, smart_shop_delivery ].compact
      else
        Delivery.shop_open + Shop::SpecialDelivery.all
      end
    deliveries.uniq.sort_by(&:date).reverse.map do |delivery|
      [ delivery.display_name, delivery.to_global_id ]
    end
  end

  def product_variants_collection(product_id)
    Shop::Product.all.includes(:variants).order_by_name.flat_map do |product|
      product.variants.map do |variant|
        [
          variant.name,
          variant.id,
          data: {
            product_id: variant.product_id,
            disabled: !!variant.out_of_stock?,
            price: catalog_price_placeholder(variant.price)
          },
          disabled: (variant.out_of_stock? || product.id != product_id)
        ]
      end
    end
  end

  def selected_shop_delivery
    gid = params.dig(:q, :_delivery_gid_eq)
    GlobalID::Locator.locate(gid) if gid.present?
  end

  def smart_shop_delivery
    Delivery.shop_open.next ||
      Shop::SpecialDelivery.next ||
      Delivery.shop_open.last ||
      Shop::SpecialDelivery.last
  end

  def delivery_title(delivery)
    title =
      case delivery
      when Delivery; Delivery.model_name.human
      when Shop::SpecialDelivery; delivery.title
      end
    t("members.shop.products.index.delivery_title",
      title: title,
      date: l(@order.delivery.date, format: :long))
  end

  def shop_invoice_period_collection
    Shop::InvoicePeriod::PERIODS.map { |period| shop_invoice_period_option(period) }
  end

  def shop_invoice_period_select(member)
    {
      collection: shop_invoice_period_options(member),
      include_blank: shop_invoice_period_blank,
      selected: member.shop_invoice_period.presence || ""
    }
  end

  def shop_invoice_period_hint
    url = handbook_page_path("shop", anchor: "group-invoicing")
    if period = organization_shop_invoice_period
      t("formtastic.hints.member.shop_invoice_period_default_html",
        period: shop_invoice_period_name(period),
        handbook_url: url)
    else
      t("formtastic.hints.member.shop_invoice_period_html", handbook_url: url)
    end
  end

  def shop_invoice_period_label(member)
    period = member.effective_shop_invoice_period
    return if period.blank?

    label = shop_invoice_period_name(period)
    return label if member.shop_invoice_period?

    t("shop.group_invoice.default", period: label)
  end

  def group_invoice_waiting_tooltip(order)
    t("shop.group_invoice.waiting_tooltip", date: group_invoice_when(order))
  end

  def group_invoice_info_html(order)
    siblings = period_orders_for(order).reject { |other| other.id == order.id }
    t("shop.group_invoice.info_html",
      when: group_invoice_when(order),
      orders: sibling_order_links(siblings))
  end

  def invoice_period_button(order)
    button_to t("shop.group_invoice.invoice_now"),
      invoice_period_shop_order_path(order),
      method: :post,
      class: "btn btn-sm",
      form: { class: "cluster is-center" },
      data: {
        confirm: future_period_delivery?(order) ? t("shop.group_invoice.future_confirm") : t("shop.group_invoice.confirm")
      }
  end

  def period_orders_for(order)
    return Shop::Order.none unless order.invoice_period_key

    order.member.shop_orders.pending
      .includes(:delivery, items: [ :product, :product_variant ])
      .select { |other| other.invoice_period_key == order.invoice_period_key }
      .sort_by { |other| [ other.delivery_date, other.id ] }
  end

  def group_invoice_when(order)
    if order.group_invoice_overdue?
      t("shop.group_invoice.next_run")
    else
      l(order.group_billing_on, format: :long)
    end
  end

  private

  def shop_invoice_period_options(member)
    periods = Shop::InvoicePeriod::PERIODS
    periods -= [ organization_shop_invoice_period ] if omit_organization_period?(member)
    periods.map { |period| shop_invoice_period_option(period) }
  end

  # A stored match is an override. Dropping it would submit blank and clear it.
  def omit_organization_period?(member)
    organization_shop_invoice_period && member.shop_invoice_period != organization_shop_invoice_period
  end

  def shop_invoice_period_blank
    return true if organization_shop_invoice_period.blank?

    t("shop.group_invoice.default", period: shop_invoice_period_name(organization_shop_invoice_period))
  end

  def shop_invoice_period_option(period)
    [ shop_invoice_period_name(period), period ]
  end

  def shop_invoice_period_name(period)
    t("shop.group_invoice.periods.#{period}")
  end

  def organization_shop_invoice_period
    Current.org.shop_invoice_period
  end

  def future_period_delivery?(order)
    period_orders_for(order).any? { |other| other.delivery_date&.future? }
  end

  def sibling_order_links(orders)
    return t("shop.group_invoice.no_other_orders") if orders.empty?

    orders.map { |other|
      link_to("##{other.id}, #{l(other.delivery_date, format: :medium)}", other)
    }.to_sentence.html_safe
  end
end
