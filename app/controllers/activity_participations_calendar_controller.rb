# frozen_string_literal: true

class ActivityParticipationsCalendarController < ApplicationController
  before_action :verify_icalendar_auth_token

  def show
    @activity_participations =
      ActivityParticipation
        .joins(:activity)
        .includes(:member)
        .where(activities: { date: 1.month.ago.. })

    fresh_when(@activity_participations)
  end

  private

  def verify_icalendar_auth_token
    token = Current.org.icalendar_auth_token

    if !token || params[:auth_token] != token
      render plain: "unauthorized", status: :unauthorized
    end
  end
end
