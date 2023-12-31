module DashboardHelper
  def onboarding?
    Delivery.none? || Depot.none? ||
      (Current.acp.member_form_mode == "membership" && BasketSize.none?)
  end
end
