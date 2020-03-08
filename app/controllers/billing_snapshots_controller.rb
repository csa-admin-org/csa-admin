class BillingSnapshotsController < ApplicationController
  include HasAuthToken

  before_action { verify_auth_token(:billing) }

  # GET billing/snapshots/:id
  def show
    @snapshot = Billing::Snapshot.find(params[:id])
    redirect_to url_for(@snapshot.file)
  end
end
