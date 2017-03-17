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
    if invoice&.persisted?
      invoice.collect_overbalances!
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
    if memberships.any?(&:billable?)
      return if quarter_already_billed? || memberships_not_started?
      attrs[:memberships_amounts_data] = memberships_amounts_data
      attrs[:memberships_amount_description] = memberships_amount_description
      attrs[:memberships_amount_fraction] = memberships_amount_fraction
    end
    invoices.create(attrs)
  end

  def support_billed?
    invoices.current_year.support.exists?
  end

  def support_amount
    Member::SUPPORT_PRICE if !support_billed? && member.support_billable?
  end

  def memberships_not_started?
    memberships.map(&:started_on).min > Time.zone.now
  end

  def memberships_amounts_data
    memberships.map do |membership|
      membership.slice(:id, :basket_id, :distribution_id).merge(
        basket_total_price: membership.basket_total_price,
        basket_description: membership.basket_description,
        distribution_total_price: membership.distribution_total_price,
        distribution_description: membership.distribution_description,
        halfday_works_total_price: membership.halfday_works_total_price,
        halfday_works_description: membership.halfday_works_description,
        description: membership.description,
        price: membership.price
      )
    end
  end

  def memberships_amount_description
    case billing_interval
    when 'annual' then 'Montant annuel'
    when 'quarterly' then "Montant trimestriel ##{quarter}"
    end
  end

  def memberships_amount_fraction
    case billing_interval
    when 'annual' then 1
    when 'quarterly' then ((13 - date.month) / 3.0).ceil
    end
  end

  def billing_interval
    member.trial? ? 'annual' : member.billing_interval
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
