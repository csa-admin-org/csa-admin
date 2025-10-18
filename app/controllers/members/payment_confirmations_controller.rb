# frozen_string_literal: true

class Members::PaymentConfirmationsController < Members::BaseController
  layout "members"
  skip_before_action :authenticate_member!

  # GET /payment_confirmation
  def show
  end

  private

  # Do not show menu.
  def current_member; nil end
end
