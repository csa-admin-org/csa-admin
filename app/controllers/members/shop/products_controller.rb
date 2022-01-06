class Members::Shop::ProductsController < Members::Shop::BaseController
  before_action :ensure_next_shop_delivery!
  before_action :find_or_create_order!
  before_action :ensure_order_cart_state!

  # GET /shop
  def index
    params.permit!
  end

  private

  def find_or_create_order!
    @order =
      delivery
        .shop_orders
        .includes(items: [:product, :product_variant])
        .find_or_create_by!(member_id: current_member.id)
  end

  def delivery
    params[:next] ? next_shop_delivery : current_shop_delivery
  end
  helper_method :delivery

  def ensure_order_cart_state!
    unless @order.cart?
      redirect_to members_shop_order_path(@order)
    end
  end

  def ensure_next_shop_delivery!
    if params[:next] && (current_shop_delivery.shop_open? || !next_shop_delivery)
      redirect_to members_shop_path
    end
  end

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

  def all_available_products(pparams = params)
    products =
      Shop::Product.available_for(
        @order.delivery,
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
