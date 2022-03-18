class Current < ActiveSupport::CurrentAttributes
  attribute :acp

  delegate :year, :range, to: :fiscal_year, prefix: :fy

  def acp
    unless super
      self.acp = ACP.find_by!(tenant_name: Tenant.current)
    end
    super
  end

  def fiscal_year
    acp.current_fiscal_year
  end
end
