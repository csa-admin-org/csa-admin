class Members::GroupBuying::BaseController < Members::BaseController
  before_action :ensure_group_buying_feature
  before_action :load_next_delivery
  before_action :ensure_next_delivery

  # GET /group_buying
  def show
    @order = @delivery.orders.new
  end

  private

  def ensure_group_buying_feature
    redirect_to members_member_path unless Current.acp.feature?('group_buying')
  end

  def load_next_delivery
    @delivery = GroupBuying::Delivery.next
  end

  def ensure_next_delivery
    redirect_to members_member_path unless @delivery
  end
end
