class InvoiceMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def created_email
    params.merge!(created_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :invoice_created)
    InvoiceMailer.with(params).created_email
  end

  def cancelled_email
    params.merge!(cancelled_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :invoice_cancelled)
    InvoiceMailer.with(params).cancelled_email
  end

  def overdue_notice_email
    params.merge!(overdue_notice_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :invoice_overdue_notice)
    InvoiceMailer.with(params).overdue_notice_email
  end

  private

  def created_email_params
    {
      member: member,
      invoice: invoice
    }
  end

  def cancelled_email_params
    {
      member: member,
      invoice: invoice
    }
  end

  def overdue_notice_email_params
    {
      member: member,
      invoice: invoice(
        overdue_notices_count: 1,
        missing_amount: 512)
    }
  end

  def invoice(**extra)
    OpenStruct.new({
      member: member,
      id: 42,
      date: Date.today,
      state: 'open',
      entity_type: Invoice.used_entity_types.sample(random: random),
      entity_number: 33,
      amount: 990,
      missing_amount: 990,
      overdue_notices_count: 0,
      pdf_file: OpenStruct.new(download: nil)
    }.merge(**extra))
  end
end


