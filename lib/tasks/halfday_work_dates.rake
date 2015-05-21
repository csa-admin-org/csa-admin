namespace :halfday_work_dates do
  desc 'Send coming halfday work emails'
  task seed: :environment do
    range = Date.new(2015, 4, 1)..Date.new(2015, 10, 31)
    range.each do |date|
      if date.monday? || date.tuesday?
        HalfdayWorkDate.create(date: date, periods: ['am', 'pm'])
      end
      if (date.friday? &&
          (date.month == 5 && date.day.in?([22, 29])) ||
          (date.month == 6 && date.day.in?([12, 19, 26])) ||
          (date.month == 7 && date.day.in?([10, 17, 24])) ||
          (date.month == 8 && date.day.in?([7, 14, 21])) ||
          (date.month == 9 && date.day.in?([4, 11, 28]))
        ) ||
        (date.saturday? &&
          (date.month == 6 && date.day == 6) ||
          (date.month == 7 && date.day == 25) ||
          (date.month == 8 && date.day == 1) ||
          (date.month == 9 && date.day == 26)
        )
        HalfdayWorkDate.create(date: date, periods: ['am'])
      end
    end
  end
end
