module Email
  include ActiveSupport::NumberHelper
  extend self

  def deliver_now(template, *args)
    params = send(template, *args)
    adapter.deliver(params)
  end

  def deliver_later(template, *args)
    DeliverJob.perform_later(template.to_s, *args)
  end

  private

  def delivery_list(delivery, distribution)
    baskets = distribution.baskets
      .not_absent
      .not_empty
      .joins(:member)
      .includes(:baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .order('members.name')
    xlsx = XLSX::Delivery.new(delivery, distribution)
    pdf = PDF::Delivery.new(delivery, distribution)

    {
      from: from,
      to: distribution.emails,
      template: template_alias(:delivery_list, distribution.email_language),
      template_data: {
        delivery_date: I18n.l(delivery.date),
        distribution_name: distribution.name,
        baskets: baskets.map { |b|
          {
            member_name: b.member.name,
            size_name: b.basket_size&.name,
            complement_names: b.complements_description
          }.compact
        }
      },
      attachments: [{
        name: xlsx.filename,
        content: xlsx.data,
        content_type: xlsx.content_type
      },{
        name: pdf.filename,
        content: pdf.render,
        content_type: pdf.content_type
      }]
    }
  end

  def halfday_reminder(halfday_participation)
    member = halfday_participation.member
    halfday = halfday_participation.halfday

    data = halfday_participation_data(halfday_participation)
    data[:halfday_participations_with_carpooling] =
      HalfdayParticipation.carpooling(halfday.date).map { |p|
        {
          member_name: p.member.name,
          carpooling_phone: p.carpooling_phone&.phony_formatted
        }
      }
    unless Current.acp.halfday_participation_deletion_deadline_in_days
      data[:action_url] = url(:members_member_url, member)
    end

    {
      from: from,
      to: member.emails,
      template: template_alias(:halfday_reminder, member.language),
      template_data: data
    }
  end

  def halfday_validated(halfday_participation)
    member = halfday_participation.member
    data = halfday_participation_data(halfday_participation)
    data[:action_url] = url(:members_member_url, member)

    {
      from: from,
      to: member.emails,
      template: template_alias(:halfday_validated, member.language),
      template_data: data
    }
  end

  def halfday_rejected(halfday_participation)
    member = halfday_participation.member
    data = halfday_participation_data(halfday_participation)
    data[:action_url] = url(:members_member_url, member)

    {
      from: from,
      to: member.emails,
      template: template_alias(:halfday_rejected, member.language),
      template_data: data
    }
  end

  def halfday_participation_data(halfday_participation)
    halfday = halfday_participation.halfday

    data = {
      halfday_date: I18n.l(halfday.date),
      halfday_date_long: I18n.l(halfday.date, format: :long),
      halfday_period: halfday.period,
      halfday_activity: halfday.activity,
      halfday_description: halfday.description,
      halfday_participants_count: halfday_participation.participants_count,
    }
    if halfday.place_url
      data[:halfday_place] = {
        name: halfday.place,
        url: halfday.place_url
      }
    else
      data[:halfday_place_name] = halfday.place
    end
    data
  end

  def invoice_new(invoice)
    {
      from: from,
      to: invoice.member.emails,
      template: template_alias(:invoice_new, invoice.member.language),
      template_data: invoice_data(invoice),
      attachments: [invoice_attachment(invoice)]
    }
  end

  def invoice_overdue_notice(invoice)
    {
      from: from,
      to: invoice.member.emails,
      template: template_alias(:invoice_overdue_notice, invoice.member.language),
      template_data: invoice_data(invoice),
      attachments: [invoice_attachment(invoice)]
    }
  end

  def invoice_data(invoice)
    data = {
      invoice_number: invoice.id,
      invoice_date: I18n.l(invoice.date),
      invoice_amount: number_to_currency(invoice.amount),
      overdue_notices_count: invoice.overdue_notices_count
    }
    if invoice.closed?
      data[:invoice_paid] = true
    elsif invoice.missing_amount < invoice.amount || invoice.overdue_notices_count.positive?
      data[:invoice_missing_amount] = number_to_currency(invoice.missing_amount)
    end
    data
  end

  def invoice_attachment(invoice)
    filename = [
      Invoice.model_name.human.downcase.parameterize,
      Current.acp.tenant_name,
      invoice.id
    ].join('-') + '.pdf'

    {
      name: filename,
      content: invoice.pdf_file.download,
      content_type: 'application/pdf'
    }
  end

  def member_new(admin, member)
    {
      from: from,
      to: admin.email,
      template: template_alias(:member_new, admin.language),
      template_data: {
        admin_name: admin.name,
        member_name: member.name,
        action_url: url(:member_url, member)
      }
    }
  end

  def member_login(member, email)
    {
      from: from,
      to: email,
      template: template_alias(:member_login, member.language),
      template_data: {
        action_url: url(:members_member_url, member)
      }
    }
  end

  def member_login_help(email, locale)
    {
      from: from,
      to: email,
      template: template_alias(:member_login_help, locale),
      template_data: {}
    }
  end

  def member_welcome(member)
    {
      from: from,
      to: member.emails,
      template: template_alias(:member_welcome, member.language),
      template_data: {
        action_url: url(:members_member_url, member)
      }
    }
  end

  def adapter
    postmark_api_token = Current.acp.credentials(:postmark_api_token)
    if (Rails.env.production? || ENV['POSTMARK_TO']) && postmark_api_token
      PostmarkAdapter.new(postmark_api_token)
    else
      MockAdapter.instance
    end
  end

  def template_alias(template, locale = nil)
    locale ||= Current.acp.language
    [template, locale].join('-').dasherize
  end

  def from
    Current.acp.email_default_from
  end

  def url(route, *args)
    params = {
      host: Current.acp.email_default_host
    }.merge(args.extract_options!)
    Rails.application.routes.url_helpers.send(route, *args, params)
  end
end
