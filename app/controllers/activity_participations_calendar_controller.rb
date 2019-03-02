class ActivityParticipationsCalendarController < ApplicationController
  include HasAuthToken

  before_action { verify_auth_token(:icalendar) }

  # GET activity_participations/calendar.ics
  def show
    @activity_participations = ActivityParticipation.all
  end
end
