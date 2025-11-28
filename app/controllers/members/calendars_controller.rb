# frozen_string_literal: true

class Members::CalendarsController < Members::BaseController
  # GET /deliveries/calendar.ics
  def show
    @baskets = @member.baskets.filled.between(period_range)
    @participations = @member.activity_participations.between(period_range)

    last_changed = [
      @baskets,
      @participations
    ].map { |rel| rel.maximum(:updated_at) }.compact.max
    fresh_when last_modified: last_changed

    @baskets =
      @baskets.includes(:delivery, :basket_size, :depot,
        baskets_basket_complements: :basket_complement)
    @activity_participations =
      ActivityParticipationGroup.group(@participations.includes(:activity))
  end

  private

  def period_range
    6.months.ago..(Current.fiscal_year.end_of_year + 1.year)
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
