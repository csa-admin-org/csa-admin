class BillingsController < ApplicationController
  before_action :authenticate_admin!

  # GET billing/:year
  def show
    xlsx = XLSX::Billing.new(params[:year].to_i)
    send_data xlsx.data,
      content_type: xlsx.content_type,
      filename: xlsx.filename
  end
end
