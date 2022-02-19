class BillingSnapshotsController < ApplicationController
  before_action :authenticate_admin!

  # GET billing/snapshots/:id
  def show
    @snapshot = Billing::Snapshot.find(params[:id])
    redirect_to url_for(@snapshot.file)
  end
end
