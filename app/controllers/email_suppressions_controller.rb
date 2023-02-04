class EmailSuppressionsController < ApplicationController
  before_action :authenticate_admin!

  # DELETE /email_suppressions/:id
  def destroy
    suppersion = EmailSuppression.find(params[:id])
    EmailSuppression.unsuppress!(suppersion.email,
      stream_id: 'outbound',
      origin: 'Customer')

    redirect_back fallback_location: root_path
  end
end
