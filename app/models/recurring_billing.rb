class RecurringBilling
  attr_reader :member, :membership, :invoices, :today, :fy_month

  def self.invoice(member, **attrs)
    new(member).invoice(**attrs)
  end

  def initialize(member, membership = nil)
    @member = member
    @membership = membership || [
      member.current_year_membership,
      member.future_membership
    ].compact.select(&:billable?).first
    @invoices = member.invoices.not_canceled.current_year
    @today = Date.current
    @fy_month = Current.acp.fy_month_for(today)
  end

  def billable?
    next_date&.in?(current_period)
  end

  def next_date
    return unless Current.acp.recurring_billing?

    @next_date ||=
      if membership&.billable?
        date =
          if current_period_billed?
            if current_period == periods.last
              next_billing_day
            else
              next_billing_day(beginning_of_next_period)
            end
          else
            next_billing_day_after_first_billable_delivery
          end
        date >= membership.fiscal_year.end_of_year ? today : date
      elsif member.support?
        if annual_fee_billable?
          next_billing_day
        else
          next_billing_day(Current.fiscal_year.end_of_year + 1.day)
        end
      end
  end

  def invoice(**attrs)
    return unless billable?

    I18n.with_locale(member.language) do
      invoice = build_invoice(**attrs)
      invoice.save
      invoice
    end
  end

  private

  def build_invoice(**attrs)
    attrs[:date] = today
    if annual_fee_billable?
      attrs[:object_type] = 'AnnualFee'
      attrs[:annual_fee] = member.annual_fee
    end
    if membership&.billable?
      attrs[:object] = membership
      attrs[:membership_amount_fraction] = membership_amount_fraction
      attrs[:memberships_amount_description] = membership_amount_description
    end

    member.invoices.build(attrs)
  end

  def annual_fee_billable?
    member.annual_fee&.positive? &&
      (member.support? || (membership.billable? && !membership.trial_only?)) &&
      invoices.annual_fee.none?
  end

  def membership_amount_fraction
    membership_end_fy_month = Current.acp.fy_month_for(membership.ended_on)
    remaining_months = [membership_end_fy_month, fy_month].max - fy_month + 1
    (remaining_months / period_length_in_months.to_f).ceil
  end

  def membership_amount_description
    fraction_number = (fy_month / period_length_in_months.to_f).ceil
    I18n.t("billing.membership_amount_description.x#{member.billing_year_division}", number: fraction_number)
  end

  def period_length_in_months
    @period_length_in_months ||= 12 / member.billing_year_division
  end

  def current_period
    @current_period ||= periods.find { |d| d.include?(today) }
  end

  def current_period_billed?
    invoices.where(object: membership).any? { |i|
      current_period.include?(i.date)
    }
  end

  def beginning_of_next_period
    current_period.max + 1.day
  end

  def periods
    @periods ||= begin
      min = Current.fiscal_year.beginning_of_year
      member.billing_year_division.times.map do |i|
        old_min = min
        max = min + period_length_in_months.months
        min = max
        old_min...max
      end
    end
  end

  def next_billing_day_after_first_billable_delivery
    baskets = membership.baskets
    basket = baskets.not_trial.first || baskets.trial.last || baskets.first
    next_billing_day(basket.delivery.date)
  end

  def next_billing_day(date = today)
    date = [date, today].compact.max.to_date
    date + ((Current.acp.recurring_billing_wday - date.wday) % 7).days
  end
end
