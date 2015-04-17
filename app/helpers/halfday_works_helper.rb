module HalfdayWorksHelper
  def display_periods(halfday_work)
    case halfday_work.periods.sort.join('')
    when 'ampm' then '8:00 - 17:30'
    when 'am' then '8:00 - 12:00'
    when 'pm' then '13:30 - 17:30'
    end
  end

  def halfday_work_summary(halfday_work)
    summary = halfday_work.member.name
    if halfday_work.participants_count > 1
      summary << " (#{halfday_work.participants_count})"
    end
    if halfday_work.pending?
      summary << ' [en attente de validation]'
    elsif halfday_work.rejected?
      summary << ' [refusée]'
    elsif halfday_work.validated?
      summary << ' [validée]'
    end
    summary
  end
end
