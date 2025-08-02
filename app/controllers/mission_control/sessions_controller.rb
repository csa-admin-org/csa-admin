# frozen_string_literal: true

class MissionControl::SessionsController < MissionControl::BaseController
  def show
    Tenant.switch(params[:tenant]) do
      session = Session.create!(
        admin_email: Admin.master.email,
        request: request)

      redirect_to session_url(session.generate_token_for(:redeem), host: Current.org.admin_url),
        allow_other_host: true
    end
  end
end
