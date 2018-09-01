module LayoutsHelper
  def nav_class(controller)
    'active' if params[:controller] == "members/#{controller}"
  end
end
