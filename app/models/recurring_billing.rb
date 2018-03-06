class RecurringBilling
  attr_reader :member, :membership, :invoices, :date

  def self.invoice(member, **attrs)
    new(member).invoice(attrs)
  end

  def initialize(member)
    @member = member
    @membership = member.current_year_membership
    @invoices = member.invoices.not_canceled.current_year
    @date = Date.current
  end

  def invoice(**attrs)
    return unless member.billable?

    attrs[:date] = date
    if support_billable?
      attrs[:support_amount] = member.support_price
    end
    if membership_billable?
      attrs[:membership] = membership
      attrs[:membership_amount_fraction] = membership_amount_fraction
      attrs[:memberships_amount_description] = membership_amount_description
    end
    member.invoices.create(attrs)
  end

  private

  def support_billable?
    member.support_price.positive? &&
      (member.support_member? ||
        (membership_billable? && !membership.trial_only?)) &&
      !support_already_billed?
  end

  def membership_billable?
    membership.present? &&
      membership.started? &&
      membership.price.positive? &&
      !membership.trial? &&
      !year_division_already_billed?
  end

  def membership_amount_fraction
    @membership_amount_fraction ||= calculate_amount_fraction(fy_month)
  end

  def membership_amount_description
    division_name = I18n.t("billing.year_division._#{year_division}")
    if year_division == 1
      "Montant #{division_name}"
    else
      fraction_number = (fy_month / (12 / year_division.to_f)).ceil
      "Montant #{division_name} ##{fraction_number}"
    end
  end

  # Bill everything if membership has been canceled (ie. trial stopped)
  def year_division
    if membership.past?
      1
    else
      member.billing_year_division
    end
  end

  def fy_month
    Current.acp.fy_month_for(date)
  end

  def support_already_billed?
    invoices.support.exists?
  end

  # We only want to bill each year division once, even when membership changes.
  # At the exception of the last year division (fraction == 1) that can be billed multiple time.
  def year_division_already_billed?
    return if membership_amount_fraction == 1
    invoices.membership.any? { |i|
      calculate_amount_fraction(i.fy_month) == membership_amount_fraction
    }
  end

  def calculate_amount_fraction(month)
    ((13 - month) / (12 / year_division.to_f)).ceil
  end
end
