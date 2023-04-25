module AbsencesHelper
  def display_absence?
    Current.acp.feature?('absence') && current_member.current_or_future_membership
  end
end
