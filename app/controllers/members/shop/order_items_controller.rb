class Members::Shop::OrderItemsController < Members::Shop::BaseController

  # POST /shop/order_items
  def create
    @item = order.items.find_or_initialize_by(product_variant_id: product_variant_id)
    @item.quantity += 1
    params.permit!

    respond_to do |format|
      if @item.save
        order.reload
        format.html { redirect_to members_shop_path }
        format.turbo_stream
      else
        format.html { render 'members/shop/products/index', status: :unprocessable_entity }
      end
    end
  end

  private

  def product_variant_id
    params.require(:variant_id)
  end
end
