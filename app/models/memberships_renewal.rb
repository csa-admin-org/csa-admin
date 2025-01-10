# frozen_string_literal: true

class MembershipsRenewal
  attr_reader :fy, :next_fy

  def initialize(year)
    @fy = Current.org.fiscal_year_for(year)
    @next_fy = Current.org.fiscal_year_for(year + 1)
    @memberships = Membership.during_year(@fy)
  end

  def fy_year
    fy.year
  end

  def future_deliveries?
    Delivery.any_in_year?(next_fy)
  end

  def actionable?
    future_deliveries? && renewable.count.positive? && fy_year >= (Current.fy_year - 1)
  end

  def to_renew
    @memberships.where(renew: true)
  end

  def renewed
    to_renew.renewed
  end

  def renewable
    to_renew.not_renewed
  end

  def opened
    renewable.where.not(renewal_opened_at: nil)
  end

  def openable
    renewable.where(renewal_opened_at: nil)
  end

  def renewing?
    latest_renewed_at = renewed.maximum(:created_at)
    latest_renewed_at && latest_renewed_at > 5.seconds.ago
  end

  def opening?
    latest_renewal_opened_at = renewable.maximum(:renewal_opened_at)
    latest_renewal_opened_at && latest_renewal_opened_at > 5.seconds.ago
  end

  def renew_all!
    unless future_deliveries?
      raise MembershipRenewal::MissingDeliveriesError, "Deliveries for next fiscal year are missing."
    end

    renewable.find_each do |membership|
      MembershipRenewalJob.perform_later(membership)
    end
  end

  def open_all!
    unless future_deliveries?
      raise MembershipRenewal::MissingDeliveriesError, "Deliveries for next fiscal year are missing."
    end

    openable.find_each do |membership|
      MembershipOpenRenewalJob.perform_later(membership)
    end
  end
end
