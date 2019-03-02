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

  def delivery_list(delivery, depot)
    I18n.with_locale(depot.language) do
      baskets = depot.baskets
        .not_absent
        .not_empty
        .includes(:basket_size, :complements, :member, :baskets_basket_complements)
        .where(delivery_id: delivery.id)
        .order('members.name')
        .uniq
      xlsx = XLSX::Delivery.new(delivery, depot)
      pdf = PDF::Delivery.new(delivery, depot)

      {
        from: from,
        to: depot.emails,
        template: template_alias(:delivery_list, depot.language),
        template_data: {
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
        },
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
  end

  def activity_participations_reminder(activity_participation)
    member = activity_participation.member
    I18n.with_locale(member.language) do
      data = activity_participation_data(activity_participation)
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
        template: template_alias(:activity_participations_reminder, member.language),
        template_data: data
      }
    end
  end

  def activity_participations_validated(activity_participation)
    member = activity_participation.member
    I18n.with_locale(member.language) do
      data = activity_participation_data(activity_participation)
      data[:action_url] = url(:members_member_url)

      {
        from: from,
        to: member.emails,
        template: template_alias(:activity_participations_validated, member.language),
        template_data: data
      }
    end
  end

  def activity_participations_rejected(activity_participation)
    member = activity_participation.member
    I18n.with_locale(member.language) do
      data = activity_participation_data(activity_participation)
      data[:action_url] = url(:members_member_url)

      {
        from: from,
        to: member.emails,
        template: template_alias(:activity_participations_rejected, member.language),
        template_data: data
      }
    end
  end

  def activity_participation_data(activity_participation)
    activity = activity_participation.activity

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

  def invoice_new(invoice)
    I18n.with_locale(invoice.member.language) do
      {
        from: from,
        to: invoice.member.emails,
        template: template_alias(:invoice_new, invoice.member.language),
        template_data: invoice_data(invoice),
        attachments: [invoice_attachment(invoice)]
      }
    end
  end

  def invoice_overdue_notice(invoice)
    I18n.with_locale(invoice.member.language) do
      {
        from: from,
        to: invoice.member.emails,
        template: template_alias(:invoice_overdue_notice, invoice.member.language),
        template_data: invoice_data(invoice),
        attachments: [invoice_attachment(invoice)]
      }
    end
  end

  def invoice_data(invoice)
    data = {
      invoice_number: invoice.id,
      invoice_date: I18n.l(invoice.date),
      invoice_amount: number_to_currency(invoice.amount),
      overdue_notices_count: invoice.overdue_notices_count,
      action_url: url(:members_billing_url)
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

  def absence_new(admin, absence)
    I18n.with_locale(admin.language) do
      {
        from: from,
        to: admin.email,
        template: template_alias(:absence_new, admin.language),
        template_data: {
          admin_name: admin.name,
          member_name: absence.member.name,
          started_on: I18n.l(absence.started_on),
          ended_on: I18n.l(absence.ended_on),
          action_url: url(:absence_url, absence),
          edit_admin_url: url(:edit_admin_url, admin, anchor: 'admin_notifications_input')
        }
      }
    end
  end

  def member_new(admin, member)
    {
      from: from,
      to: admin.email,
      template: template_alias(:member_new, admin.language),
      template_data: {
        admin_name: admin.name,
        member_name: member.name,
        action_url: url(:member_url, member),
        edit_admin_url: url(:edit_admin_url, admin, anchor: 'admin_notifications_input')
      }
    }
  end

  def member_login(member, email, action_url)
    {
      from: from,
      to: email,
      template: template_alias(:member_login, member.language),
      template_data: {
        action_url: action_url
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
        action_url: url(:members_member_url)
      }
    }
  end

  def admin_reset_password(admin, token)
    {
      from: from,
      to: admin.email,
      template: template_alias(:admin_reset_password, admin.language),
      template_data: {
        admin_name: admin.name,
        action_url: url(:edit_admin_password_url, admin, reset_password_token: token)
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

  def template_alias(template, locale)
    [template, locale].join('-').dasherize
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
