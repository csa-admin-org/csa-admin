# frozen_string_literal: true

class BillingsController < ApplicationController
  include UncachedSendData

  before_action :authenticate_admin!

  def show
    xlsx = XLSX::Billing.new(params[:year].to_i)
    send_data xlsx.data,
      content_type: xlsx.content_type,
      filename: xlsx.filename
  end
end
