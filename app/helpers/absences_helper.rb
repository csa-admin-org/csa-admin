# frozen_string_literal: true

module AbsencesHelper
  def display_absence?
    Current.org.feature?("absence") && current_member.current_or_future_membership
  end
end
