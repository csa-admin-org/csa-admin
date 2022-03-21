module DashboardHelper
  def onboarding?
    Delivery.none? || Depot.none? || BasketSize.none?
  end
end
