# frozen_string_literal: true

class EBICSOnboardingMailer < ApplicationMailer
  def setup_submitted_notification_email
    prepare_notification("setup_submitted")

    mail(notification_mail_options(
      subject: "[EBICS] Setup submitted for #{Current.org.name}",
      tag: "ebics-onboarding-setup-submitted-notification"))
  end

  def support_needed_notification_email
    prepare_notification("support_needed")

    mail(notification_mail_options(
      subject: "[EBICS] Setup needs support for #{Current.org.name}",
      tag: "ebics-onboarding-support-needed-notification"))
  end

  def finalized_notification_email
    prepare_notification("finalized")

    mail(notification_mail_options(
      subject: "[EBICS] Setup finalized for #{Current.org.name}",
      tag: "ebics-onboarding-finalized-notification"))
  end

  private

  def prepare_notification(event)
    @connection = params[:connection]
    @event = event
    @settings_url = organization_url(anchor: "bank_connection", host: Current.org.admin_url)
    @letter_url = ebics_initialization_letter_url(host: Current.org.admin_url)
    @context = notification_context
  end

  def notification_mail_options(subject:, tag:)
    {
      to: ultra_admin_email,
      reply_to: initiated_by_admin_email,
      subject: subject,
      tag: tag
    }.compact
  end

  def ultra_admin_email
    Admin.ultra&.email || ENV.fetch("ULTRA_ADMIN_EMAIL")
  end

  def initiated_by_admin_email
    onboarding_status["initiated_by_admin_email"].presence
  end

  def notification_context
    {
      tenant: Tenant.current,
      organization: Current.org.name,
      country_code: Current.org.country_code,
      bank_connection_id: @connection.id,
      bank: @connection.name,
      provider: @connection.provider,
      active: @connection.active?,
      state: @connection.state,
      health_status: @connection.health_status,
      onboarding_state: onboarding_status["state"],
      target_bits: onboarding_status["target_bits"],
      initiated_at: onboarding_status["initiated_at"],
      initiated_by_admin_email: onboarding_status["initiated_by_admin_email"],
      ini_submitted_at: onboarding_status["ini_submitted_at"],
      hia_submitted_at: onboarding_status["hia_submitted_at"],
      finalized_at: onboarding_status["finalized_at"],
      last_finalization_check_at: onboarding_status["last_finalization_check_at"],
      last_finalization_status: onboarding_status["last_finalization_status"],
      finalization_return_code: onboarding_status["finalization_return_code"],
      last_error_class: @connection.last_error_class,
      last_error_message: @connection.last_error_message
    }.compact_blank
  end

  def onboarding_status
    @onboarding_status ||= @connection.status_details.to_h.dig("onboarding").to_h.deep_stringify_keys
  end
end
