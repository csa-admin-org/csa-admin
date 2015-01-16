class NextDeliveryController < ApplicationController
  before_action :verify_auth_token

  # GET /deliveries/next.xlsx
  def next
    @delivery = Delivery.coming.first
    @filter_distribution = Distribution.find(2) # Vélo
    render xlsx: 'deliveries/show',
      filename: "RageDeVert-Livraison-#{@delivery.date.strftime("%Y%m%d")}"
  end

  private

  def verify_auth_token
    unless params[:auth_token] == ENV['DELIVERY_AUTH_TOKEN']
      render text: 'unauthorized', status: :unauthorized
    end
  end
end
