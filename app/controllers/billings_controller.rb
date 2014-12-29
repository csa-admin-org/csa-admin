class BillingsController < ApplicationController
  # GET billing.xls
  def show
    @billing = Billing.all_for_xls

    respond_to do |format|
      format.xls do
        send_data(@billing.to_xls,
          type: 'application/excel; charset=utf-8; header=present',
          filename: "RageDeVert-Facturation-#{Date.today_2015.strftime("%Y%m%d-%Hh%M")}.xls"
        )
      end
    end
  end
end
