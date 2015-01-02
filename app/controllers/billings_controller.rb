class BillingsController < ApplicationController
  # GET billing.xlsx
  def show
    @billings = Billing.all
    respond_to do |format|
      format.xlsx {
        render xlsx: :show,
          filename: "RageDeVert-Facturation-#{Time.zone.now.strftime("%Y%m%d-%Hh%M")}"
      }
    end
  end
end
