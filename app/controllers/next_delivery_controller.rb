class NextDeliveryController < ApplicationController
  before_action :verify_auth_token

  def self.controller_path
    'deliveries'
  end

  # GET /deliveries/next.xlsx
  def next
    @delivery = Delivery.coming.first
    @filter_distribution = Distribution.find(2) # Vélo
    render(
      xlsx: :show,
      filename: "RageDeVert-Livraison-#{@delivery.date.strftime("%Y%m%d")}"
    )
  end

  private

  def verify_auth_token
    unless params[:auth_token] == ENV['DELIVERY_AUTH_TOKEN']
      render plain: 'unauthorized', status: :unauthorized
    end
  end
end
