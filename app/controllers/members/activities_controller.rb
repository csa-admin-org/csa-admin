class Members::ActivitiesController < Members::BaseController
  skip_before_action :authenticate_member!

  # GET /activities.rss
  def index
    @activities = Activity.available
    @limit = params[:limit]&.to_i || 8
    respond_to do |format|
      format.rss
    end
  end
end
