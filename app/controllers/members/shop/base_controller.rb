class Members::Shop::BaseController < Members::BaseController
  before_action :ensure_shop_feature
  before_action :ensure_delivery

  private

  def ensure_shop_feature
    redirect_to members_member_path unless Current.acp.feature?('shop')
  end

  def ensure_delivery
    unless delivery
      redirect_to members_member_path
    end
  end

  def shop_path
    case @order&.delivery
    when next_shop_delivery; members_shop_next_path
    when Shop::SpecialDelivery; members_shop_special_delivery_path(@order.delivery.date)
    else members_shop_path
    end
  end
  helper_method :shop_path
end

