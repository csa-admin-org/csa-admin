# frozen_string_literal: true

class Members::PublicPagesController < Members::BaseController
  skip_before_action :authenticate_member!
  before_action :redirect_current_member!

  # GET /:page (welcome, goodbye)
  def show
    render params[:page]
  end

  private

  def redirect_current_member!
    redirect_to members_member_path if current_member
  end
end
