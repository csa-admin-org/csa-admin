# frozen_string_literal: true

class EBICSOnboardingLettersController < ApplicationController
  include UncachedSendData

  before_action :authenticate_admin!

  def show
    if bank_connection = onboarding_bank_connection
      I18n.with_locale(locale) do
        pdf = PDF::EBICSInitializationLetter.new(bank_connection)
        send_data pdf.render,
          content_type: pdf.content_type,
          filename: pdf.filename,
          disposition: "inline"
      end
    else
      redirect_back fallback_location: organization_path,
        notice: t("ebics.initialization_letter.unavailable")
    end
  end

  private

  def onboarding_bank_connection
    connections = BankConnection.where(
      provider: "ebics",
      state: %w[initializing waiting_for_bank]).select do |connection|
        Billing::EBICS::Onboarding.new(tenant: Tenant.current, connection: connection).letter_available?
      end

    connections.first if connections.one?
  end

  def locale
    params[:locale].to_s.first(2).presence_in(I18n.available_locales.map(&:to_s)) || I18n.locale
  end
end
