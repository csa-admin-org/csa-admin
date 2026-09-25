# frozen_string_literal: true

module Shop
  module InvoicePeriod
    PERIODS = %w[month quarter year].freeze

    module_function

    def key_for(period, date)
      case period
      when "month"
        date.strftime("%Y-%m")
      when "quarter"
        "#{date.year}-Q#{date.quarter}"
      when "year"
        date.year.to_s
      end
    end

    def billing_on(period, date)
      case period
      when "month"
        date.beginning_of_month.next_month
      when "quarter"
        date.beginning_of_quarter.next_quarter
      when "year"
        date.beginning_of_year.next_year
      end
    end

    def due?(period, date, on: Date.current)
      billing = billing_on(period, date)
      billing.present? && billing <= on
    end
  end
end
