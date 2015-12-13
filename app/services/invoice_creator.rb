class InvoiceCreator
  attr_reader :member, :memberships, :invoices, :date

  def initialize(member)
    @member = member
    @memberships = member.current_year_memberships.all
    @invoices = member.invoices
    @date = Time.zone.today
  end

  def create
    invoice = create_invoice
    if invoice.try(:persisted?)
      # InvoiceMailer.new_invoice(invoice).deliver_later
      invoice
    end
  end

  private

  def create_invoice
    attributes = {
      date: date,
      support_amount: support_amount
    }
    if memberships.any?(&:billable?)
      return if quarter_already_billed?
      attributes.merge!(
        memberships_amounts_data: memberships_amounts_data,
        memberships_amount_description: memberships_amount_description,
        memberships_amount_fraction: memberships_amount_fraction
      )
    end
    invoices.create(attributes)
  end

  def support_billed?
    invoices.current_year.support.exists?
  end

  def support_amount
    Member::SUPPORT_PRICE if !support_billed? && member.support_billable?
  end

  def memberships_amounts_data
    memberships.map do |membership|
      membership.slice(:id, :description).merge(amount: membership.price)
    end
  end

  def memberships_amount_description
    case member.billing_interval
    when 'annual' then 'Montant annuel'
    when 'quarterly' then "Montant trimestriel ##{quarter}"
    end
  end

  def memberships_amount_fraction
    case member.billing_interval
    when 'annual' then 1
    when 'quarterly' then ((13 - date.month) / 3.0).ceil
    end
  end

  def quarter
    (date.month / 3.0).ceil
  end

  # We only want to bill the first three quarters once, even when memberships
  # change. Last quarter can have many invoices when memberships change like
  # yearly members.
  def quarter_already_billed?
    if memberships_amount_fraction != 1
      invoices.current_year.quarter(quarter).exists?
    end
  end
end
