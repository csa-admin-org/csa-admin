class MembershipsRenewal
  attr_reader :next_fy

  def initialize
    @next_fy = Current.acp.fiscal_year_for(1.year.from_now)
  end

  def to_renew
    Membership.current_year.where(renew: true)
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
    unless Delivery.any_next_year?
      raise MembershipRenewal::MissingDeliveriesError, "Deliveries for next fiscal year are missing."
    end

    renewable.find_each do |membership|
      MembershipRenewalJob.perform_later(membership)
    end
  end

  def open_all!
    unless Delivery.any_next_year?
      raise MembershipRenewal::MissingDeliveriesError, "Deliveries for next fiscal year are missing."
    end

    openable.find_each do |membership|
      MembershipOpenRenewalJob.perform_later(membership)
    end
  end
end
