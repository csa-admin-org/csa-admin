# frozen_string_literal: true

class AdminMailer < ApplicationMailer
  include ActivitiesHelper

  def depot_delivery_list_email
    depot = params[:depot]
    delivery = params[:delivery]
    baskets = params[:baskets] || depot.baskets_for(delivery)
    I18n.with_locale(depot.language) do
      xlsx = XLSX::Delivery.new(delivery, depot)
      attachments[xlsx.filename] = {
        mime_type: xlsx.content_type,
        content: xlsx.data
      }
      pdf = PDF::Delivery.new(delivery, depot)
      attachments[pdf.filename] = {
        mime_type: pdf.content_type,
        content: pdf.render
      }
      content = liquid_template.render(
        "depot" => Liquid::DepotDrop.new(depot),
        "baskets" => baskets.map { |b| Liquid::AdminBasketDrop.new(b) },
        "delivery" => Liquid::DeliveryDrop.new(delivery))
      content_mail(content,
        to: depot.emails_array,
        subject: t(".subject",
          date: I18n.l(delivery.date),
          depot: depot.name),
        tag: "admin-depot-delivery-list")
    end
  end

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
        subject: t_activity(".subject"),
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
end
