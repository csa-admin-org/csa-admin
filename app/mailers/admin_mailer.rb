# frozen_string_literal: true

class AdminMailer < ApplicationMailer
  def delivery_list_email
    @admin = params[:admin]
    delivery = params[:delivery]
    I18n.with_locale(@admin.language) do
      xlsx = XLSX::Delivery.new(delivery)
      attachments[xlsx.filename] = {
        mime_type: xlsx.content_type,
        content: xlsx.data
      }
      pdf = PDF::Delivery.new(delivery)
      attachments[pdf.filename] = {
        mime_type: pdf.content_type,
        content: pdf.render
      }
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "delivery" => Liquid::AdminDeliveryDrop.new(delivery))
      content_mail(content,
        to: @admin.email,
        subject: t(".subject", date: I18n.l(delivery.date)),
        tag: "admin-delivery-list")
    end
  end

  def invitation_email
    admin = params[:admin]
    I18n.with_locale(admin.language) do
      content = liquid_template.render(
        "organization" => Liquid::OrganizationDrop.new(Current.org),
        "admin" => Liquid::AdminDrop.new(admin),
        "action_url" => params[:action_url],
        "demo" => Tenant.demo?)
      subject_key = Tenant.demo? ? ".subject_demo" : ".subject"
      @signature = "#{I18n.t("organization.default_email_signature")}\n#{Admin.ultra.name}" if Tenant.demo?
      content_mail(content,
        to: admin.email,
        subject: t(subject_key, org: Current.org.name),
        tag: "admin-invitation")
    end
  end

  def invoice_overpaid_email
    @admin = params[:admin]
    I18n.with_locale(@admin.language) do
      invoice = Liquid::InvoiceDrop.new(params[:invoice])
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(params[:member]),
        "invoice" => invoice)
      content_mail(content,
        to: @admin.email,
        subject: t(".subject", number: invoice.number),
        tag: "admin-invoice-overpaid")
    end
  end

  def invoice_third_overdue_notice_email
    @admin = params[:admin]
    @invoice = params[:invoice]
    I18n.with_locale(@admin.language) do
      invoice = Liquid::InvoiceDrop.new(@invoice)
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(@invoice.member),
        "invoice" => invoice)
      content_mail(content,
        to: @admin.email,
        subject: t(".subject", number: invoice.number),
        tag: "admin-invoice-third-overdue-notice")
    end
  end

  def payment_reversal_email
    @admin = params[:admin]
    @payment = params[:payment]
    I18n.with_locale(@admin.language) do
      payment = Liquid::PaymentDrop.new(@payment)
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(params[:member]),
        "payment" => payment,
        "invoice" => payment.invoice)
      content_mail(content,
        to: @admin.email,
        subject: t(".subject", number: payment.invoice.number),
        tag: "admin-payment-reversal")
    end
  end

  def new_absence_email
    @admin = params[:admin]
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(params[:member]),
        "absence" => Liquid::AdminAbsenceDrop.new(params[:absence]))
      content_mail(content,
        to: @admin.email,
        reply_to: params[:reply_to],
        subject: t(".subject"),
        tag: "admin-absence-created")
    end
  end

  def new_activity_participation_email
    @admin = params[:admin]
    @participation =
      if params[:activity_participation]
        params[:activity_participation]
      else
        participations = ActivityParticipation.where(id: params[:activity_participation_ids])
        ActivityParticipationGroup.new(participations)
      end
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(@participation.member),
        "activity" => Liquid::ActivityDrop.new(@participation.activity),
        "activity_participation" => Liquid::AdminActivityParticipationDrop.new(@participation))
      content_mail(content,
        to: @admin.email,
        reply_to: params[:reply_to],
        subject: t(".subject"),
        tag: "admin-activity-participation-created")
    end
  end

  def new_email_suppression_email
    @admin = params[:admin]
    @email_suppression = params[:email_suppression]
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "email_suppression" => Liquid::EmailSuppressionDrop.new(@email_suppression))
      content_mail(content,
        to: @admin.email,
        subject: t(".subject", reason: @email_suppression.reason),
        tag: "admin-email-suppression-created")
    end
  end

  def new_registration_email
    @admin = params[:admin]
    existing = params[:existing] || false
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(params[:member], existing: existing))
      content_mail(content,
        to: @admin.email,
        subject: t(".subject.#{existing ? "existing" : "new"}"),
        tag: "admin-member-created")
    end
  end

  def new_shop_order_email
    @admin = params[:admin]
    order = params[:shop_order]
    I18n.with_locale(@admin.language) do
      shop_order = Liquid::AdminShopOrderDrop.new(order)
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(order.member),
        "shop_order" => shop_order)
      content_mail(content,
        to: @admin.email,
        subject: t(".subject", number: shop_order.id),
        tag: "admin-shop-order-received")
    end
  end

  def membership_trial_cancelation_email
    @admin = params[:admin]
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(@admin),
        "member" => Liquid::AdminMemberDrop.new(params[:member]),
        "membership" => Liquid::AdminMembershipDrop.new(params[:membership]))
      content_mail(content,
        to: @admin.email,
        subject: t(".subject"),
        tag: "admin-membership-trial-cancelation")
    end
  end

  def demo_registration_notification_email
    admin = params[:admin]
    message = params[:message]
    tenant = params[:tenant]
    I18n.with_locale("en") do
      lines = []
      lines << "<p><strong>Name:</strong> #{ERB::Util.html_escape(admin.name)}</p>"
      lines << "<p><strong>Email:</strong> #{ERB::Util.html_escape(admin.email)}</p>"
      lines << "<p><strong>Message:</strong> #{ERB::Util.html_escape(message)}</p>" if message
      lines << "<p><strong>Tenant:</strong> #{ERB::Util.html_escape(tenant)}</p>"
      lines << "<p><strong>Time:</strong> #{I18n.l(Time.current)}</p>"
      lines.concat(demo_page_visit_summary_lines(admin))
      content_mail(lines.join("\n"),
        to: ENV["ULTRA_ADMIN_EMAIL"],
        subject: "[Demo] New registration: #{admin.name} (#{admin.email})",
        tag: "admin-demo-registration-notification")
    end
  end

  def demo_follow_up_email
    admin = params[:admin]
    setup_handbook_url = params[:setup_handbook_url]
    I18n.with_locale(admin.language) do
      content = liquid_template.render(
        "admin" => Liquid::AdminDrop.new(admin),
        "setup_handbook_url" => setup_handbook_url)
      @signature = "#{I18n.t("organization.default_email_signature")}\n#{Admin.ultra.name}"
      content_mail(content,
        to: admin.email,
        subject: t(".subject"),
        tag: "admin-demo-follow-up")
    end
  end

  def demo_follow_up_notification_email
    admin = params[:admin]
    tenant = params[:tenant]
    I18n.with_locale("en") do
      lines = []
      lines << "<p><strong>Name:</strong> #{ERB::Util.html_escape(admin.name)}</p>"
      lines << "<p><strong>Email:</strong> #{ERB::Util.html_escape(admin.email)}</p>"
      lines << "<p><strong>Tenant:</strong> #{ERB::Util.html_escape(tenant)}</p>"
      lines << "<p><strong>Time:</strong> #{I18n.l(Time.current)}</p>"
      content_mail(lines.join("\n"),
        to: ENV["ULTRA_ADMIN_EMAIL"],
        subject: "[Demo] Follow-up sent: #{admin.name} (#{admin.email})",
        tag: "admin-demo-follow-up-notification")
    end
  end

  def memberships_renewal_pending_email
    @admin = params[:admin]
    @subject_class = "alert"
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        "organization" => Liquid::OrganizationDrop.new(Current.org),
        "admin" => Liquid::AdminDrop.new(@admin),
        "pending_memberships" => params[:pending_memberships].map { |m| Liquid::AdminMembershipDrop.new(m) },
        "opened_memberships" => params[:opened_memberships].map { |m| Liquid::AdminMembershipDrop.new(m) },
        "pending_action_url" => params[:pending_action_url],
        "opened_action_url" => params[:opened_action_url],
        "action_url" => params[:action_url])
      content_mail(content,
        to: @admin.email,
        subject: t(".subject"),
        tag: "admin-memberships-renewal-pending")
    end
  end

  private

  def demo_page_visit_summary_lines(admin)
    return [] unless admin.persisted?

    visits = admin.demo_page_visits.meaningful
    return [] unless visits.exists?

    [
      "<p><strong>Page visits:</strong> #{visits.count}</p>",
      "<p><strong>Distinct pages:</strong> #{visits.distinct.count(:page_key)}</p>",
      "<p><strong>First visit:</strong> #{I18n.l(visits.minimum(:created_at))}</p>",
      "<p><strong>Last visit:</strong> #{I18n.l(visits.maximum(:created_at))}</p>",
      "<p><strong>Top pages:</strong> #{demo_page_visit_top_pages(visits)}</p>"
    ]
  end

  def demo_page_visit_top_pages(visits)
    visits
      .group(:page_key)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(5)
      .count
      .map { |page_key, count| "#{ERB::Util.html_escape(page_key)} (#{count})" }
      .join(", ")
  end
end
