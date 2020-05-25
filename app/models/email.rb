module Email
  include ActiveSupport::NumberHelper
  extend self

  def deliver_now(template, *args)
    return unless enabled?(template)

    params = send(template, *args)
    adapter.deliver(params)
  end

  def deliver_later(template, *args)
    DeliverJob.perform_later(template.to_s, *args)
  end

  private

  def admin_absence_new(admin, absence)
    data = template_data(admin.language) do
      {
        admin_name: admin.name,
        member_name: absence.member.name,
        started_on: I18n.l(absence.started_on),
        ended_on: I18n.l(absence.ended_on),
        action_url: url(:absence_url, absence),
        edit_admin_url: url(:edit_admin_url, admin, anchor: 'admin_notifications_input')
      }
    end

    {
      from: from,
      to: admin.email,
      template: 'admin-absence-new',
      template_data: data
    }
  end

  def admin_delivery_list(delivery, depot)
    baskets = depot.baskets
      .not_absent
      .not_empty
      .includes(:basket_size, :complements, :member, :baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .order('members.name')
      .uniq
    xlsx = XLSX::Delivery.new(delivery, depot)
    pdf = PDF::Delivery.new(delivery, depot)

    data = template_data(depot.language) do
      {
        delivery_date: I18n.l(delivery.date),
        depot_name: depot.name,
        baskets: baskets.map { |b|
          {
            member_name: b.member.name,
            description: b.description,
            size_name: b.basket_size&.name,
            complement_names: b.complements_description
          }.compact
        }
      }
    end

    {
      from: from,
      to: depot.emails,
      template: 'admin-delivery-list',
      template_data: data,
      attachments: [{
        name: xlsx.filename,
        content: xlsx.data,
        content_type: xlsx.content_type
      }, {
        name: pdf.filename,
        content: pdf.render,
        content_type: pdf.content_type
      }]
    }
  end

  def admin_invitation(admin)
    data = template_data(admin.language) do
      {
        admin_name: admin.name,
        admin_email: admin.email,
        action_url: url(:root_url),
        edit_admin_url: url(:edit_admin_url, admin, anchor: 'admin_notifications_input')
      }
    end

    {
      from: from,
      to: admin.email,
      template: 'admin-invitation',
      template_data: data
    }
  end

  def admin_invoice_overpaid(admin, invoice)
    data = template_data(admin.language) do
      {
        admin_name: admin.name,
        invoice_number: invoice.id,
        member_name: invoice.member.name,
        action_url: url(:member_url, invoice.member),
        edit_admin_url: url(:edit_admin_url, admin, anchor: 'admin_notifications_input')
      }
    end

    {
      from: from,
      to: admin.email,
      template: 'admin-invoice-overpaid',
      template_data: data
    }
  end

  def admin_member_new(admin, member)
    data = template_data(admin.language) do
      {
        admin_name: admin.name,
        member_name: member.name,
        action_url: url(:member_url, member),
        edit_admin_url: url(:edit_admin_url, admin, anchor: 'admin_notifications_input')
      }
    end

    {
      from: from,
      to: admin.email,
      template: 'admin-member-new',
      template_data: data
    }
  end

  def member_activity_reminder(activity_participation)
    member = activity_participation.member
    data = activity_data(activity_participation)
    data[:activity_participations_with_carpooling] =
      ActivityParticipation
        .where(activity_id: activity_participation.activity_id)
        .carpooling
        .includes(:member)
        .map { |p|
          {
            member_name: p.member.name,
            carpooling_phone: p.carpooling_phone&.phony_formatted,
            carpooling_city: p.carpooling_city
          }
        }
    unless Current.acp.activity_participation_deletion_deadline_in_days
      data[:action_url] = url(:members_member_url)
    end

    {
      from: from,
      to: member.emails,
      template: 'member-activity-reminder',
      template_data: data
    }
  end

  def member_activity_validated(activity_participation)
    member = activity_participation.member
    data = activity_data(activity_participation)
    data[:action_url] = url(:members_member_url)

    {
      from: from,
      to: member.emails,
      template: 'member-activity-validated',
      template_data: data
    }
  end

  def member_activity_rejected(activity_participation)
    member = activity_participation.member
    data = activity_data(activity_participation)
    data[:action_url] = url(:members_member_url)

    {
      from: from,
      to: member.emails,
      template: 'member-activity-rejected',
      template_data: data
    }
  end

  def activity_data(activity_participation)
    activity = activity_participation.activity
    member = activity_participation.member
    template_data(member.language) do
      data = {
        activity_date: I18n.l(activity.date),
        activity_date_long: I18n.l(activity.date, format: :long),
        activity_period: activity.period,
        activity_title: activity.title,
        activity_description: activity.description,
        activity_participants_count: activity_participation.participants_count
      }
      if activity.place_url
        data[:activity_place] = {
          name: activity.place,
          url: activity.place_url
        }
      else
        data[:activity_place_name] = activity.place
      end
      data
    end
  end

  def member_invoice_new(invoice)
    {
      from: from,
      to: invoice.member.emails,
      template: 'member-invoice-new',
      template_data: invoice_data(invoice),
      attachments: [invoice_attachment(invoice)]
    }
  end

  def member_invoice_overdue_notice(invoice)
    {
      from: from,
      to: invoice.member.emails,
      template: 'member-invoice-overdue-notice',
      template_data: invoice_data(invoice),
      attachments: [invoice_attachment(invoice)]
    }
  end

  def invoice_data(invoice)
    member = invoice.member
    template_data(member.language) do
      data = {
        invoice_number: invoice.id,
        invoice_date: I18n.l(invoice.date),
        invoice_amount: number_to_currency(invoice.amount),
        overdue_notices_count: invoice.overdue_notices_count,
        action_url: url(:members_billing_url)
      }
      data[invoice.object_type.underscore.tr('/', '_').to_sym] = true
      if invoice.closed?
        data[:invoice_paid] = true
      elsif invoice.missing_amount < invoice.amount || invoice.overdue_notices_count.positive?
        data[:invoice_missing_amount] = number_to_currency(invoice.missing_amount)
      end
      data
    end
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

  def member_validated(member)
    data = template_data(member.language) do
      {
        action_url: url(:members_member_url),
        members_waiting_count: Member.waiting.count
      }
    end

    {
      from: from,
      to: member.emails,
      template: 'member-validated',
      template_data: data
    }
  end

  def member_welcome(member)
    data = template_data(member.language) do
      { action_url: url(:members_member_url) }
    end

    {
      from: from,
      to: member.emails,
      template: 'member-welcome',
      template_data: data
    }
  end

  def session_new(owner, email, action_url, data = {})
    data = template_data(owner.language) do
      { action_url: action_url }.merge(data)
    end

    {
      from: from,
      to: email,
      template: 'session-new',
      template_data: data.merge(data)
    }
  end

  def templates
    default = %w[
      admin_absence_new
      admin_delivery_list
      admin_invitation
      admin_invoice_overpaid
      admin_member_new
      member_activity_reminder
      member_activity_validated
      member_activity_rejected
      member_invoice_new
      member_invoice_overdue_notice
      member_welcome
      session_new
    ]
    default += Current.acp.email_notifications
    default
  end

  def enabled?(template)
    template.to_s.in?(templates)
  end

  def adapter
    postmark_api_token = Current.acp.credentials(:postmark, :api_token)
    if (Rails.env.production? || ENV['POSTMARK_TO']) && postmark_api_token
      PostmarkAdapter.new(postmark_api_token)
    else
      MockAdapter.instance
    end
  end

  def template_data(locale)
    I18n.with_locale(locale) do
      data = yield
      data[locale.to_sym] = true
      data
    end
  end

  def from
    Current.acp.email_default_from
  end

  def url(route, *args)
    params = {
      host: Current.acp.email_default_host
    }.merge(args.extract_options!)
    Rails.application.routes.url_helpers
      .send(route, *args, params)
      .sub(%r{/\z}, '')
  end
end
