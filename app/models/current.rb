# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :session

  delegate :year, :range, to: :fiscal_year, prefix: :fy

  resets { @org = nil; @fiscal_year = nil }

  def org
    @org ||= Organization.instance
  end

  # Picks the next fiscal year when no deliveries exist in the current one.
  def fiscal_year
    @fiscal_year ||= begin
      current = org.current_fiscal_year
      if Delivery.during_year(current.year).none? && Delivery.during_year(current.year + 1).any?
        org.next_fiscal_year
      else
        current
      end
    end
  end
end
