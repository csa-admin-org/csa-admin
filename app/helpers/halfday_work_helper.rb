module HalfdayWorkHelper
  def diplay_periods(periods)
    case periods.sort.join('')
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
    summary
  end
end
