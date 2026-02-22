# frozen_string_literal: true

class EmailSuppressionsController < ApplicationController
  before_action :authenticate_admin!

  def destroy
    suppersion = EmailSuppression.find(params[:id])
    suppersion.unsuppress!

    redirect_back fallback_location: root_path
  end
end
