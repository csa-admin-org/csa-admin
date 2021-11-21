class Members::Shop::ProductsController < Members::Shop::BaseController
  before_action :ensure_order_cart_state!

  # GET /shop
  def index
    params.permit!
  end

  private

  def ensure_order_cart_state!
    unless order.cart?
      redirect_to members_shop_order_path
    end
  end
end
