# frozen_string_literal: true

class Demo::RegistrationsController < ApplicationController
  include CapVerifiable

  helper ActiveAdmin::LayoutHelper
  layout "active_admin_logged_out"

  prepend_before_action :ensure_demo_tenant!

  def new
    @registration = Demo::Registration.new
  end

  def create
    @registration = Demo::Registration.new(registration_params)
    @registration.request = request
    if @registration.save
      redirect_to login_path, notice: t("sessions.flash.initiated")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def ensure_demo_tenant!
    redirect_to login_path unless Tenant.demo?
  end

  def registration_params
    params.require(:demo_registration).permit(:name, :email, :message)
  end

  def cap_after_failure
    @registration = Demo::Registration.new(registration_params)
    flash.now[:alert] = t("cap.failed_retry")
    render :new, status: :unprocessable_entity
  end
end
