class HalfdayWorksCalendarController < ApplicationController
  include HasAuthToken

  before_action { verify_auth_token(:icalendar) }

  # GET halfday_works/calendar.ics
  def show
    @halfday_participations = HalfdayParticipation.all
  end
end
