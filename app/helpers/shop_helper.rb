# frozen_string_literal: true

module ShopHelper
  def show_shop_menu?
    return unless Current.org.feature?("shop")
    return unless current_shop_delivery || shop_special_deliveries.any?

    !Current.org.shop_admin_only || current_session.admin_originated?
  end

  def smart_shop_orders_path
    delivery =
      Delivery.shop_open.next ||
        Shop::SpecialDelivery.next ||
        Delivery.shop_open.last ||
        Shop::SpecialDelivery.last
    if delivery
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
        Delivery.shop_open.joins(:shop_orders).distinct +
          Shop::SpecialDelivery.joins(:shop_orders).distinct
      else
        Delivery.shop_open + Shop::SpecialDelivery.all
      end
    deliveries.sort_by(&:date).reverse.map do |delivery|
      [ delivery.display_name, delivery.to_global_id ]
    end
  end

  def product_variants_collection(product_id)
    Shop::Product.all.includes(:variants).order_by_name.flat_map do |product|
      product.variants.map do |variant|
        [
          variant.name,
          variant.id,
          data: { product_id: variant.product_id, disabled: !!variant.out_of_stock? },
          disabled: (variant.out_of_stock? || product.id != product_id)
        ]
      end
    end
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
end
