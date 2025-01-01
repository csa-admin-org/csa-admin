# frozen_string_literal: true

module OrganizationsHelper
  def org(columns = {})
    Current.org.update_columns(columns)
  end
end
