class Current < ActiveSupport::CurrentAttributes
  attribute :session

  delegate :year, :range, to: :fiscal_year, prefix: :fy

  resets { @acp = nil }

  def acp
    @acp ||= ACP.find_by!(tenant_name: Tenant.current)
  end

  def fiscal_year
    acp.current_fiscal_year
  end

  # AcitveJob inline queue adapter is reseting the Current attributes
  # after each run. This is a workaround to keep the Current attributes
  # set when a job is performed inline in a spec and only reset the
  # current attributes when the Tenant is switched.
  # https://github.com/rails/rails/issues/36298
  if Rails.env.test?
    def reset
      run_callbacks :reset do
        super if caller[5].include?('/lib/tenant.rb')
      end
    end
  end
end
