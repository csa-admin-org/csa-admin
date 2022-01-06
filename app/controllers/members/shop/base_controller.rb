class Members::Shop::BaseController < Members::BaseController
  before_action :ensure_shop_feature_flag
  before_action :ensure_delivery

  private

  def ensure_shop_feature_flag
    redirect_to members_member_path unless Current.acp.feature_flag?('shop')
  end

  def ensure_delivery
    unless current_shop_delivery || next_shop_delivery
      redirect_to members_member_path
    end
  end

  def shop_path
    case @order&.delivery
    when next_shop_delivery; members_shop_next_path
    else members_shop_path
    end
  end
  helper_method :shop_path
end

