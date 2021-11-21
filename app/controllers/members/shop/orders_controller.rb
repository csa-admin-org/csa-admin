class Members::Shop::OrdersController < Members::Shop::BaseController
  before_action :ensure_order_not_empty
  before_action :ensure_order_state

  # GET /shop/order
  def show
    respond_to do |format|
      format.html {  render :show }
      format.turbo_stream
    end
  end

  # PUT/PATCH /shop/order
  def update
    respond_to do |format|
      if order.update(order_params)
        if order.items.empty?
          format.html { redirect_to members_shop_path }
          format.turbo_stream { redirect_to members_shop_path }
        else
          format.html { redirect_to members_shop_order_path }
          format.turbo_stream
        end
      else
        format.html { render :show, status: :unprocessable_entity }
        format.turbo_stream
      end
    end
  end

  # POST /shop/order/confirm
  def confirm
    order.confirm!
    redirect_to members_shop_order_path, notice: t('.notice')
  rescue InvalidTransitionError, ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  # POST /shop/order/unconfirm
  def unconfirm
    order.unconfirm!
    redirect_to members_shop_order_path
  rescue InvalidTransitionError
    render :show, status: :unprocessable_entity
  end


  # DELETE /shop/order
  def destroy
    order.destroy
    redirect_to members_shop_path
  end

  private

  def ensure_order_not_empty
    if order.items.empty?
      redirect_to members_shop_path, status: :see_other
    end
  end

  def ensure_order_state
    if order.cart? && !delivery.shop_open?
      redirect_to members_shop_path, status: :see_other
    end
  end

  def order_params
    params
      .require(:shop_order)
      .permit(
        items_attributes: %i[id quantity])
      .tap do |whitelisted|
        whitelisted[:items_attributes].each do |_, item|
          if item[:quantity] == '0'
            item.delete(:quantity)
            item[:_destroy] = true
          end
        end
      end
  end
end
