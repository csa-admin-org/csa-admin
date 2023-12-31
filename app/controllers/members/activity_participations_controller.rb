class Members::ActivityParticipationsController < Members::BaseController
  include ActivitiesHelper

  before_action :ensure_activity_access

  # GET /activity_participations
  def index
    @activities = Activity.available_for(current_member)
    @activity_participation = ActivityParticipation.new(
      activity: @activities.select(&:missing_participants?).first || @activities.first)
    @activity_participation.carpooling_phone ||= current_member.phones_array.first
    @activity_participation.carpooling_city ||= current_member.city
  end

  # POST /activity_participations
  def create
    @activity_participation = current_member.activity_participations.new(protected_params)
    @activity_participation.session_id = session_id

    if @activity_participation.save
      flash[:notice] = t(".flash.notice")
      redirect_to members_activity_participations_path
    else
      @activities = Activity.available_for(current_member)
      unless @activity_participation.carpooling
        @activity_participation.carpooling_phone ||= current_member.phones_array.first
        @activity_participation.carpooling_city ||= current_member.city
      end
      render :index, status: :unprocessable_entity
    end
  end

  # DELETE /activity_participations/:id
  def destroy
    participation = current_member.activity_participations.find(params[:id])
    participation.destroy if participation.destroyable?

    redirect_to members_activity_participations_path
  end

  private

  def protected_params
    params
      .require(:activity_participation)
      .permit(%i[participants_count note carpooling carpooling_phone carpooling_city], activity_ids: [])
  end

  def ensure_activity_access
    redirect_to members_member_path unless display_activity?
  end
end
