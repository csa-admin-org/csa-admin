class Current < ActiveSupport::CurrentAttributes
  delegate :year, :range, to: :fiscal_year, prefix: :fy

  resets { @acp = nil }

  def acp
    @acp ||= ACP.find_by!(tenant_name: Tenant.current)
  end

  def fiscal_year
    acp.current_fiscal_year
  end
end
