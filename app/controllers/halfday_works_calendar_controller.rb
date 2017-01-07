class HalfdayWorksCalendarController < ApplicationController
  before_action :verify_auth_token

  # GET halfday_works/calendar.ics
  def show
    @halfday_participations = HalfdayParticipation.all
  end

  private

  def verify_auth_token
    unless params[:auth_token] == ENV['ICALENDAR_AUTH_TOKEN']
      render plain: 'unauthorized', status: :unauthorized
    end
  end
end
