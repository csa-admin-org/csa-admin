# frozen_string_literal: true

class Members::NewsletterDeliveriesController < Members::BaseController
  PER_PAGE = 20

  before_action :ensure_deliveries

  # GET /newsletters
  def index
    offset = params[:offset].to_i
    @newsletters = Newsletter.for(current_member)
    @next_offset = offset + PER_PAGE
    @next_offset = nil unless @newsletters.count > @next_offset
    @newsletters = @newsletters.offset(offset).first(PER_PAGE)
  end

  # GET /newsletters
  def show
    @delivery = current_member.newsletter_deliveries.find(params[:id])
    render layout: false
  end

  private

  def ensure_deliveries
    return if Newsletter.for(current_member).any?

    redirect_to members_login_path
  end
end
