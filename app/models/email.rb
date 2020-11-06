module Email
  include NumbersHelper
  extend self

  def deliver_now(template, *args)
    return unless enabled?(template)

    params = send(template, *args)
    adapter.deliver(**params)
  end

  def deliver_later(template, *args)
    DeliverJob.perform_later(template.to_s, *args)
  end

  private

  def member_activated(member)
    membership = member.current_or_future_membership

    data = template_data(member.language) do
      {
        action_url: url(:members_member_url),
        membership_start_date: I18n.l(membership.started_on),
        membership_end_date: I18n.l(membership.ended_on),
        first_delivery_data: I18n.l(membership.deliveries.first.date),
        "basket_size_id_#{membership.basket_size_id}": true,
        "depot_id_#{membership.depot_id}": true,
        trial_baskets: membership.remaning_trial_baskets_count,
        activity_participations_demanded: membership.activity_participations_demanded
      }
    end
    membership.memberships_basket_complements.pluck(:basket_complement_id).each do |bc_id|
      data[:"basket_complement_id_#{bc_id}"] = true
    end

    {
      from: from,
      to: member.emails,
      template: 'member-activated',
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
        invoice_amount: cur(invoice.amount),
        overdue_notices_count: invoice.overdue_notices_count,
        action_url: url(:members_billing_url)
      }
      data[invoice.object_type.underscore.tr('/', '_').to_sym] = true
      if invoice.closed?
        data[:invoice_paid] = true
      elsif invoice.missing_amount < invoice.amount || invoice.overdue_notices_count.positive?
        data[:invoice_missing_amount] = cur(invoice.missing_amount)
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

  def member_renewal(membership)
    member = membership.member
    data = template_data(member.language) do
      {
        action_url: url(:members_membership_url, hanchor: 'renewal'),
        membership_start_date: I18n.l(membership.started_on),
        membership_end_date: I18n.l(membership.ended_on)
      }
    end

    {
      from: from,
      to: member.emails,
      template: 'member-renewal',
      template_data: data
    }
  end

  def member_renewal_reminder(membership)
    member = membership.member
    data = template_data(member.language) do
      {
        action_url: url(:members_membership_url, hanchor: 'renewal'),
        membership_start_date: I18n.l(membership.started_on),
        membership_end_date: I18n.l(membership.ended_on)
      }
    end

    {
      from: from,
      to: member.emails,
      template: 'member-renewal-reminder',
      template_data: data
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

  def templates
    default = %w[
      member_activity_reminder
      member_activity_validated
      member_activity_rejected
      member_invoice_new
      member_invoice_overdue_notice
      member_renewal
      member_renewal_reminder
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
