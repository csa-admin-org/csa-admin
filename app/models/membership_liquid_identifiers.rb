# frozen_string_literal: true

module MembershipLiquidIdentifiers
  def started_fy_month
    return unless @membership.started_on

    @membership.fiscal_year.fy_month(@membership.started_on)
  end

  def started_day
    @membership.started_on&.day
  end

  def basket_size_id
    @membership.basket_size_id
  end

  def delivery_cycle_id
    @membership.delivery_cycle_id
  end
end
