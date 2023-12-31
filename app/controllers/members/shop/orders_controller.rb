class Members::Shop::OrdersController < Members::Shop::BaseController
  before_action :find_order
  before_action :ensure_order_not_empty
  before_action :ensure_order_state

  # GET /shop/orders/:id
  def show
    respond_to do |format|
      format.html { render :show }
      format.turbo_stream
    end
  end

  # PUT/PATCH /shop/orders/:id
  def update
    respond_to do |format|
      if @order.update(order_params)
        if @order.items.empty?
          format.html { redirect_to shop_path }
          format.turbo_stream { redirect_to shop_path }
        else
          format.html { redirect_to members_shop_order_path(@order) }
          format.turbo_stream
        end
      else
        format.html { render :show, status: :unprocessable_entity }
        format.turbo_stream
      end
    end
  end

  # POST /shop/orders/:id/confirm
  def confirm
    @order.confirm!
    redirect_to members_shop_order_path(@order), notice: t(".notice")
  rescue InvalidTransitionError, ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  # POST /shop/orders/:id/unconfirm
  def unconfirm
    @order.unconfirm!
    redirect_to members_shop_order_path(@order)
  rescue InvalidTransitionError
    render :show, status: :unprocessable_entity
  end

  # DELETE /shop/orders/:id
  def destroy
    @order.destroy
    redirect_to shop_path
  end

  private

  def find_order
    @order ||=
      Shop::Order
        .where(delivery: [ current_shop_delivery, next_shop_delivery, *shop_special_deliveries ].compact)
        .where(member_id: current_member.id)
        .includes(items: [ :product, :product_variant ])
        .find(params[:id])
  end

  def delivery
    find_order&.delivery
  end
  helper_method :delivery

  def ensure_order_not_empty
    if @order.items.empty?
      redirect_to shop_path, status: :see_other
    end
  end

  def ensure_order_state
    if @order.cart? && !@order.shop_open?
      redirect_to shop_path, status: :see_other
    end
  end

  def order_params
    params
      .require(:shop_order)
      .permit(:amount_percentage, items_attributes: %i[id quantity])
      .tap do |whitelisted|
        unless whitelisted[:amount_percentage].to_i.in?(Current.acp[:shop_member_percentages])
          whitelisted[:amount_percentage] = nil
        end
        whitelisted[:items_attributes].each do |_, item|
          if item[:quantity] == "0"
            item.delete(:quantity)
            item[:_destroy] = true
          end
        end
      end
  end
end
