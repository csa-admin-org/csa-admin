module DeliveriesHelper
  extend self

  def create_deliveries(count, fiscal_year = Current.fiscal_year)
    return if Delivery.any_in_year?(fiscal_year)

    date = fiscal_year.beginning_of_year.beginning_of_week + 8.days
    count.times.each do
      Delivery.new(date: date).save!(validate: false)
      date += 1.week
    end
  end
end

RSpec.configure do |config|
  config.include(DeliveriesHelper)
end
