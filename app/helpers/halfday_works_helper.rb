module HalfdayWorksHelper
  def display_periods(halfday_work)
    if halfday_work.date.wednesday?
      case halfday_work.periods.sort.join('')
      when 'ampm' then '7:00 - 10:00 / 13:30 - 17:30'
      when 'am' then '7:00 - 10:00'
      when 'pm' then '13:30 - 17:30'
      end
    else
      case halfday_work.periods.sort.join('')
      when 'ampm' then '8:30 - 12:00 / 13:30 - 17:30'
      when 'am' then '8:30 - 12:00'
      when 'pm' then '13:30 - 17:30'
      end
    end
  end

  def display_locations(halfday_work, format: :long)
    locations = []
    if halfday_work.date.wednesday? && halfday_work.am?
      locations <<
        case format
        when :long then 'Jardin de la Main à Neuchâtel, https://goo.gl/maps/tUQcLu1KkPN2'
        when :short then link_to('Neuchâtel', 'https://goo.gl/maps/tUQcLu1KkPN2', title: 'Google Maps')
        end
    else
      locations <<
        case format
        when :long then 'Aux champs à Thielle devant le grand chêne, https://goo.gl/maps/xSxmiYRhKWH2'
        when :short then link_to('Thielle', 'https://goo.gl/maps/xSxmiYRhKWH2', title: 'Google Maps')
        end
    end
    locations.join(' / ')
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
