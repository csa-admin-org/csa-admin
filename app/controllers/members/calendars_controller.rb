# frozen_string_literal: true

class Members::CalendarsController < Members::BaseController
  def show
    range = period_range
    baskets = @member.baskets.filled.between(range)
    participations = @member.activity_participations.between(range)

    last_changed = [
      baskets.maximum(:updated_at),
      participations.maximum(:updated_at)
    ].compact.max
    return unless stale?(last_modified: last_changed)

    @calendar_last_modified = last_changed || Time.current
    @baskets =
      baskets.includes(:delivery, :basket_size, :depot,
        baskets_basket_complements: :basket_complement)
    @activity_participations =
      ActivityParticipationGroup.group(participations.includes(:activity))
  end

  private

  def period_range
    6.months.ago..(Current.fiscal_year.end_of_year + 1.year)
  end

  def current_member
    @member
  end

  def authenticate_member!
    @member = Member.kept.find_by_token_for(:calendar, params[:token])

    unless @member
      render plain: "unauthorized", status: :unauthorized
    end
  end
end
