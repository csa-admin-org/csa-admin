module GroupBuyingHelper
  def next_group_buying_delivery
    @next_group_buying_delivery ||= GroupBuying::Delivery.next
  end

  def display_group_buying?
    Current.acp.feature?('group_buying') && next_group_buying_delivery &&
      current_member.id.in?([110128, 110019])
  end
end
