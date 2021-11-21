class Members::Shop::BaseController < Members::BaseController
  before_action :ensure_shop_feature_flag
  before_action :ensure_delivery

  private

  def delivery
    @delivery ||=
      Delivery
        .shop_open
        .where(id: current_member.baskets.coming.pluck(:delivery_id))
        .next
  end
  helper_method :delivery

  def next_delivery
    @next_delivery ||=
      Delivery
        .shop_open
        .where.not(id: delivery.id)
        .where(id: current_member.baskets.coming.pluck(:delivery_id))
        .next
  end
  helper_method :next_delivery

  def order
    @order ||= delivery.shop_orders.includes(items: [:product, :product_variant]).find_or_create_by!(member_id: current_member.id)
  end
  helper_method :order

  def available_products
    @available_products ||= all_available_products
  end
  helper_method :available_products

  def available_producers
    @available_producers ||=
      all_available_products(params.slice(:tag_id))
        .map(&:producer)
        .compact
        .uniq
        .sort_by(&:name)
  end
  helper_method :available_producers

  def available_tags
    @available_tags ||=
      all_available_products(params.slice(:producer_id))
        .flat_map(&:tags)
        .uniq
        .sort_by(&:name)
  end
  helper_method :available_tags

  def ensure_shop_feature_flag
    redirect_to members_member_path unless Current.acp.feature_flag?('shop')
  end

  def ensure_delivery
    redirect_to members_member_path unless delivery
  end

  def all_available_products(pparams = params)
    products =
      Shop::Product.available_for(
        delivery,
        current_member.next_basket.depot)
      .preload(:variants, :tags, :producer, "rich_text_description_#{I18n.locale}".to_sym)
    if pparams[:producer_id].present?
      products = products.where(producer_id: pparams[:producer_id])
    end
    if pparams[:tag_id].present?
      products =
        products
          .joins(:shop_products_tags)
          .where(shop_products_tags: { tag_id: pparams[:tag_id] })
    end
    products
  end
end

