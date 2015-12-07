class ComingHalfdayWorkDates
  attr_reader :coming_halfday_work_dates, :coming_halfday_works_by_date

  def initialize
    @coming_halfday_work_dates = HalfdayWorkDate.after_next_week.to_a
    @coming_halfday_works_by_date = HalfdayWork.coming.group_by(&:date)
  end

  def dates_with_participants_count
    coming_halfday_work_dates.each_with_object({}) do |halfday_work_date, hash|
      hash.merge!(
        halfday_work_date.date.to_s => participant_counts(halfday_work_date)
      )
    end
  end

  def min
    @coming_halfday_work_dates.min_by(&:date).try(:date) || Time.zone.today
  end

  def max
    @coming_halfday_work_dates.max_by(&:date).try(:date) || Time.zone.today
  end

  private

  def participant_counts(halfday_work_date)
    ampm_counts = ampm_counts(halfday_work_date)
    if halfday_works = coming_halfday_works_by_date[halfday_work_date.date]
      halfday_works.each do |halfday_work|
        if halfday_work_date.am? && halfday_work.am?
          ampm_counts[0] += halfday_work.participants_count
        end
        if halfday_work_date.pm? && halfday_work.pm?
          ampm_counts[1] += halfday_work.participants_count
        end
      end
    end
    ampm_counts
  end

  def ampm_counts(halfday_work_date)
    counts = []
    counts << (halfday_work_date.am? ? 0 : nil)
    counts << (halfday_work_date.pm? ? 0 : nil)
    counts
  end
end
