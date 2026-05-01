# frozen_string_literal: true

class Members::SEPAMandatesController < Members::BaseController
  before_action :ensure_sepa_capable

  def new
    @sepa_mandate = current_member.sepa_mandates.build
  end

  def create
    @sepa_mandate = current_member.sepa_mandates.build(sepa_mandate_params)

    if @sepa_mandate.save
      redirect_to members_billing_path,
        notice: t("members.sepa_mandates.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    current_member.disable_sepa!
    redirect_to members_billing_path,
      notice: t("members.disable_sepa.flash.notice")
  end

  private

  def sepa_mandate_params
    params.require(:sepa_mandate).permit(:iban, :sepa_mandate_accepted).merge(
      source: "self-service",
      ip: request.remote_ip,
      user_agent: request.user_agent)
  end

  def ensure_sepa_capable
    unless Current.org.sepa? && Current.org.sepa_creditor_identifier?
      redirect_to members_billing_path
    end
  end
end
