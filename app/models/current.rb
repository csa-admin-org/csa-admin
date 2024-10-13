# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :session

  delegate :year, :range, to: :fiscal_year, prefix: :fy

  resets { @org = nil }

  def org
    @org ||= Organization.find_by!(tenant_name: Tenant.current)
  end

  def fiscal_year
    org.current_fiscal_year
  end
end
