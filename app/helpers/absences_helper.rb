module AbsencesHelper
  def display_absence?
    Current.acp.feature?('absence') && !current_member.inactive?
  end
end
