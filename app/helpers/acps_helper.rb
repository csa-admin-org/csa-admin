module AcpsHelper
  def feature?(feature)
    Current.acp.feature?(feature)
  end
end
