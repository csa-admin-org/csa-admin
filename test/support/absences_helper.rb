# frozen_string_literal: true

module AbsencesHelper
  def create_absence(attributes = {})
    Absence.create!({
      member: members(:john),
      admin: admins(:super),
    }.merge(attributes))
  end
end
