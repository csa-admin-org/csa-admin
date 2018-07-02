class Members::HalfdaysController < Members::BaseController
  skip_before_action :authenticate_member!

  # GET /halfdays.rss
  def index
    @halfdays = Halfday.available
    @limit = params[:limit]&.to_i || 8
    respond_to do |format|
      format.rss
    end
  end
end
