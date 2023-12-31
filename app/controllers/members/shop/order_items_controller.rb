class Members::Shop::OrderItemsController < Members::Shop::BaseController
  before_action :find_order

  # POST /shop/orders/:order_id/order_items
  def create
    @item = @order.items.find_or_initialize_by(product_variant_id: product_variant_id) do |i|
      i.quantity = 0
    end
    @item.quantity += 1
    params.permit!

    respond_to do |format|
      if @item.save
        @order.reload
        format.html { redirect_to shop_path }
        format.turbo_stream
      else
        format.html { render "members/shop/products/index", status: :unprocessable_entity }
      end
    end
  end

  private

  def find_order
    @order ||=
      Shop::Order
      .where(delivery: [ current_shop_delivery, next_shop_delivery, *shop_special_deliveries ].compact)
      .where(member_id: current_member.id)
        .includes(items: [ :product, :product_variant ])
        .find(params[:order_id])
  end

  def delivery
    find_order&.delivery
  end
  helper_method :delivery

  def product_variant_id
    params.require(:variant_id)
  end
end
