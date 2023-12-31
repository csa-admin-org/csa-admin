class ActivityParticipationsCalendarController < ApplicationController
  before_action :verify_icalendar_auth_token

  # GET activity_participations/calendar.ics
  def show
    @activity_participations =
      ActivityParticipation
        .joins(:activity)
        .includes(:member)
        .where("activities.date >= ?", 1.month.ago)
  end

  private

  def verify_icalendar_auth_token
    token = Current.acp.icalendar_auth_token

    if !token || params[:auth_token] != token
      render plain: "unauthorized", status: :unauthorized
    end
  end
end
