# frozen_string_literal: true

class Members::NewsletterDeliveriesController < Members::BaseController
  PER_PAGE = 20

  before_action :ensure_deliveries

  def index
    offset = params[:offset].to_i
    @deliveries = Newsletter.deliveries_for(current_member)
    @next_offset = offset + PER_PAGE
    @next_offset = nil unless @deliveries.count > @next_offset
    @deliveries = @deliveries.offset(offset).first(PER_PAGE)
  end

  def show
    @delivery = current_member.mail_deliveries.newsletters.find(params[:id])
    render layout: false
  end

  private

  def ensure_deliveries
    return if MailDelivery.newsletters.processed.exists?(member: current_member)

    redirect_to members_login_path
  end
end
