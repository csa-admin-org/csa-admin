# frozen_string_literal: true

module Analytics::Year
  def empty? = count.zero?
  def in_progress? = !fiscal_year.past?
end
