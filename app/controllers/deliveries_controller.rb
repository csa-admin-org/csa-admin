class DeliveriesController < ApplicationController
  # GET billing.xlsx
  def show
    respond_to do |format|
      format.xlsx {
        render xlsx: :show,
          filename: "RageDeVert-Livraison-#{Time.zone.now.strftime("%Y%m%d-%Hh%M")}"
      }
    end
  end
end
