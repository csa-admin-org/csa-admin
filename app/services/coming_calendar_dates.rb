class ComingCalendarDates
  attr_reader :comings_halfday_works_by_date

  def self.dates_with_participants_count
    new.dates_with_participants_count
  end

  def initialize
    @comings_halfday_works_by_date = HalfdayWork.coming.group_by(&:date)
  end

  def dates_with_participants_count
    selectable_dates.each_with_object({}) do |date, hash|
      hash.merge!(date.to_s => participant_counts(date))
    end
  end

  private

  def selectable_dates
    range = Date.today..Date.today.end_of_year
    range.select { |date| date.monday? || date.tuesday? }
  end

  def participant_counts(date)
    ampm_counts = [0, 0]
    if halfday_works = comings_halfday_works_by_date[date]
      halfday_works.each do |halfday_work|
        ampm_counts[0] += halfday_work.participants_count if halfday_work.am?
        ampm_counts[1] += halfday_work.participants_count if halfday_work.pm?
      end
    end
    ampm_counts
  end
end
