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
        .includes(items: [ :product, :product_variant ])
        .find_or_create_by!(member_id: current_member.id)
  end

  def delivery
    if params[:next]
      next_shop_delivery
    elsif params[:special_delivery_date]
      shop_special_deliveries.detect { |d| d.date.to_s == params[:special_delivery_date] }
    else
      current_shop_delivery
    end
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
end
