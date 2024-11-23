# frozen_string_literal: true

class Members::CalendarsController < Members::BaseController
  # GET /deliveries/calendar.ics
  def show
    @baskets =
      @member
        .baskets
        .filled
        .between(period_range)
        .includes(:basket_size, :depot, baskets_basket_complements: :basket_complement)
    participations =
      @member
        .activity_participations
        .between(period_range)
        .includes(:activity)
    @activity_participations = ActivityParticipationGroup.group(participations)
  end

  private

  def period_range
    fy = Current.fiscal_year
    (fy.beginning_of_year - 1.year)..(fy.end_of_year + 1.year)
  end

  def current_member
    @member
  end

  def authenticate_member!
    @member = Member.find_by_token_for(:calendar, params[:token])

    unless @member
      render plain: "unauthorized", status: :unauthorized
    end
  end
end
