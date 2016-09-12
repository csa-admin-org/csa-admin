class ComingHalfdayWorkDates
  attr_reader :coming_halfday_work_dates, :coming_halfday_works_by_date

  def initialize
    @coming_halfday_work_dates = HalfdayWorkDate.after_next_week.order(:date).to_a
    @coming_halfday_works_by_date = HalfdayWork.coming.group_by(&:date)
  end

  def dates_with_participants_count
    coming_halfday_work_dates.group_by(&:date).each_with_object({}) do |(date, halfday_work_dates), hash|
      hash[date.to_s] = participant_counts(date, halfday_work_dates)
    end
  end

  def min
    @coming_halfday_work_dates.min_by(&:date).try(:date) || Time.zone.today
  end

  def max
    @coming_halfday_work_dates.max_by(&:date).try(:date) || Time.zone.today
  end

  private

  def participant_counts(date, halfday_work_dates)
    ampm_counts = ampm_counts(halfday_work_dates)
    if halfday_works = coming_halfday_works_by_date[date]
      halfday_works.each do |halfday_work|
        if ampm_counts[0].is_a?(Integer) && halfday_work.am?
          ampm_counts[0] += halfday_work.participants_count
        end
        if ampm_counts[1].is_a?(Integer) && halfday_work.pm?
          ampm_counts[1] += halfday_work.participants_count
        end
      end
    end
    ampm_counts
  end

  def ampm_counts(halfday_work_dates)
    periods = [nil, nil]
    am = halfday_work_dates.find(&:am?)
    if am
      periods[0] = am.am_full? ? :full : 0
    end
    pm = halfday_work_dates.find(&:pm?)
    if pm
      periods[1] = pm.pm_full? ? :full : 0
    end
    periods
  end
end
