# frozen_string_literal: true

# Handles activity participation tracking and calculations for memberships.
#
# Activity participations are optional volunteer hours that members contribute
# to the CSA. This concern manages the demanded, accepted, and missing counts,
# as well as the associated price adjustments.
#
# Key Concepts:
#   - demanded_annually: Number of participations expected based on basket size/complements
#   - demanded: Actual number demanded after applying delivery count ratio
#   - accepted: Number of participations completed or invoiced
#   - missing: Difference between demanded and accepted
#
# The activity feature can be disabled per organization via Current.org.feature?("activity").
#
module Membership::Activity
  extend ActiveSupport::Concern

  included do
    validates :activity_participations_demanded_annually, numericality: true
    validates :activity_participations_annual_price_change, numericality: true, allow_nil: true

    scope :activity_participations_missing_eq, ->(count) {
      where("MAX(activity_participations_demanded - activity_participations_accepted, 0) = ?", count.to_i)
    }
    scope :activity_participations_missing_gt, ->(count) {
      where("MAX(activity_participations_demanded - activity_participations_accepted, 0) > ?", count.to_i)
    }
    scope :activity_participations_missing_lt, ->(count) {
      where("MAX(activity_participations_demanded - activity_participations_accepted, 0) < ?", count.to_i)
    }

    before_validation :set_activity_participations_demanded_annually_default
    before_save :set_activity_participations
  end

  def activity_participations_annual_price_change=(price)
    super price.presence && rounded_price(price.to_f)
  end

  def activity_participations_demanded_annually_by_default
    return 0 unless Current.org.feature?("activity")

    count = basket_quantity * basket_size&.activity_participations_demanded_annually
    memberships_basket_complements.each do |mbc|
      count += mbc.quantity * mbc.basket_complement&.activity_participations_demanded_annually.to_i
    end
    count
  end

  def activity_participations_demanded_diff_from_default
    copy = dup
    copy.activity_participations_demanded_annually = activity_participations_demanded_annually_by_default
    activity_participations_demanded - ActivityParticipationDemanded.new(copy).count
  end

  def activity_participations_missing
    return 0 if trial? || trial_only?

    [ activity_participations_demanded - activity_participations_accepted, 0 ].max
  end

  def update_activity_participations_accepted!
    participations = member.activity_participations.not_rejected.during_year(fiscal_year)
    invoices = member.invoices.not_canceled.activity_participations_fiscal_year(fiscal_year)
    update_column(
      :activity_participations_accepted,
      participations.sum(:participants_count) + invoices.sum(:missing_activity_participations_count))
  end

  def clear_activity_participations_demanded!
    return unless Current.org.feature?("activity")

    update_column(:activity_participations_demanded, 0)
  end

  def can_clear_activity_participations_demanded?
    return false unless Current.org.feature?("activity")

    fiscal_year.past? && activity_participations_demanded > activity_participations_accepted
  end

  private

  def set_activity_participations_demanded_annually_default
    self.activity_participations_demanded_annually ||= activity_participations_demanded_annually_by_default
  end

  def set_activity_participations
    if Current.org.feature?("activity")
      self.activity_participations_demanded = ActivityParticipationDemanded.new(self).count
      self.activity_participations_annual_price_change ||=
        -1 * activity_participations_demanded_diff_from_default * Current.org.activity_price
    else
      self.activity_participations_demanded = 0
      self.activity_participations_annual_price_change = 0
    end
  end
end
