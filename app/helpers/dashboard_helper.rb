module DashboardHelper
  def onboarding?
    Delivery.none? || Depot.kept.none? ||
      (Current.acp.member_form_mode == "membership" && BasketSize.kept.none?)
  end
end
