# frozen_string_literal: true

class Members::NewsletterDeliveriesController < Members::BaseController
  PER_PAGE = 20

  before_action :ensure_deliveries

  def index
    offset = params[:offset].to_i
    page = Newsletter.deliveries_for(current_member)
      .without_content
      .offset(offset)
      .limit(PER_PAGE + 1)
      .to_a

    @next_offset = offset + PER_PAGE if page.size > PER_PAGE
    @deliveries = page.first(PER_PAGE)
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
