class InvoiceCreator
  attr_reader :member, :membership, :invoices, :date

  def initialize(member)
    @member = member
    @membership = member.current_year_membership
    @invoices = member.invoices.not_canceled.current_year
    @date = Date.current
  end

  def create
    invoice = create_invoice
    if invoice&.persisted?
      Payment.update_invoices_balance!(invoice.member)
      invoice.set_pdf
      invoice
    end
  rescue => ex
    ExceptionNotifier.notify_exception(ex)
    nil
  end

  private

  def create_invoice
    attrs = {
      date: date,
      support_amount: support_amount,
      member_billing_interval: billing_interval
    }
    if membership&.billable?
      return if quarter_already_billed? || !membership.started?
      attrs[:membership] = membership
      attrs[:membership_amount_fraction] = membership_amount_fraction
      attrs[:memberships_amount_description] = membership_amount_description
    end
    invoices.create(attrs)
  end

  def support_billed?
    invoices.support.exists?
  end

  def support_amount
    Member::SUPPORT_PRICE if !support_billed? && member.support_billable?
  end

  def membership_amount_description
    case billing_interval
    when 'annual' then 'Montant annuel'
    when 'quarterly' then "Montant trimestriel ##{fy_quarter}"
    end
  end

  def membership_amount_fraction
    case billing_interval
    when 'annual' then 1
    when 'quarterly' then ((13 - fy_month) / 3.0).ceil
    end
  end

  def billing_interval
    member.trial? ? 'annual' : member.billing_interval
  end

  def fy_quarter
    (fy_month / 3.0).ceil
  end

  def fy_month
    Current.acp.fiscal_year_for(date).month(date)
  end

  # We only want to bill the first three quarters once, even when memberships
  # change. Last quarter can have many invoices when memberships change like
  # yearly members.
  def quarter_already_billed?
    if membership_amount_fraction != 1
      invoices.any? { |i| i.fy_quarter == fy_quarter }
    end
  end
end
