class Members::ActivitiesController < Members::BaseController
  skip_before_action :authenticate_member!

  # GET /activities.rss
  def index
    @activities = Activity.available
    @limit = params[:limit]&.to_i || 8
    respond_to do |format|
      format.rss
      format.html { redirect_to members_activity_participations_path }
    end
  end
end
