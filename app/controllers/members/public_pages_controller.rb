# frozen_string_literal: true

class Members::PublicPagesController < Members::BaseController
  skip_before_action :authenticate_member!
  before_action :redirect_current_member!

  ALLOWED_PAGES = %w[welcome goodbye].freeze

  # GET /:page (welcome, goodbye)
  def show
    page = params[:page]
    render page if ALLOWED_PAGES.include?(page)
  end

  private

  def redirect_current_member!
    redirect_to members_member_path if current_member
  end
end
