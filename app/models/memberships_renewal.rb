class MembershipsRenewal
  MissingDeliveriesError = Class.new(StandardError)

  attr_reader :next_fy

  def initialize
    @next_fy = Current.acp.fiscal_year_for(1.year.from_now)
  end

  def to_renew
    Membership.current_year.where(renew: true)
  end

  def renewed
    Membership.during_year(@next_fy).where(member_id: to_renew.pluck(:member_id))
  end

  def renewable
    to_renew.where.not(member_id: renewed.pluck(:member_id))
  end

  def renewing?
    latest_renewed_at = renewed.maximum(:created_at)
    latest_renewed_at && latest_renewed_at > 5.seconds.ago
  end

  def renew
    unless next_year_deliveries?
      raise MissingDeliveriesError, 'Deliveries for next fiscal year are missing.'
    end

    renewable.find_each do |membership|
      RenewalJob.perform_later(membership, @next_fy.year)
    end
  end

  def next_year_deliveries?
    Delivery.between(@next_fy.range).any?
  end
end
