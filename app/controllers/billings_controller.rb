class BillingsController < ApplicationController
  # GET billing.xlsx
  def show
    @delivery = Delivery.find(params[:id])
    respond_to do |format|
      format.xlsx {
        render xlsx: :show,
          filename: "RageDeVert-Livraison-#{Delivery.next_coming_date.strftime("%Y%m%d")}"
      }
    end
  end
end
