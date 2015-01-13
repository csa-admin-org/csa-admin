class BillingsController < ApplicationController
  # GET billing.xlsx
  def show
    @memberships = Membership.billable
    @members = Member.support
    respond_to do |format|
      format.xlsx {
        render xlsx: :show,
          filename: "RageDeVert-Facturation-#{Time.zone.now.strftime("%Y%m%d-%Hh%M")}"
      }
    end
  end
end
