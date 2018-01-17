class BillingsController < ApplicationController
  before_action :verify_auth_token

  # GET billing/:year
  def show
    xlsx = XLSX::Billing.new(params[:year].to_i)
    send_data xlsx.data,
      content_type: xlsx.content_type,
      filename: xlsx.filename
  end

  private

  def verify_auth_token
    if params[:auth_token] != ENV['BILLING_AUTH_TOKEN'] && !admin_signed_in?
      render plain: 'unauthorized', status: :unauthorized
    end
  end
end
