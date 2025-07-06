# frozen_string_literal: true

class BiddingRound < ApplicationRecord
  include HasState

  has_states :draft, :open, :failed, :completed

  has_many :pledges, class_name: "BiddingRound::Pledge", dependent: :destroy
  has_many :memberships, through: :pledges

  has_rich_text :description

  validates :fiscal_year, presence: true
  validate :fiscal_year_must_be_current_or_future
  validate :only_one_draft
  validate :only_one_open
  validate :memberships_must_exist_for_fiscal_year

  scope :during_year, ->(year) {
    fy_year = Current.org.fiscal_year_for(year).year
    where(fy_year: fy_year)
  }
  scope :for_member, ->(member) {
    joins(:pledges).where(pledges: { member: member })
  }

  before_create :set_number

  def self.current_draft
    draft.first
  end

  def self.current_open
    open.first
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[during_year]
  end


  def fiscal_year
    @fiscal_year ||= Current.org.fiscal_year_for(fy_year)
  end

  def current_year?
    fiscal_year == Current.fiscal_year
  end

  def current_or_future_year?
    fiscal_year >= Current.fiscal_year
  end

  def title
    I18n.t("bidding_rounds.title", year: fiscal_year.to_s, number: number)
  end

  def total_expected_value
    @total_expected_value ||=
      eligible_memberships.joins(:basket_size).sum("basket_sizes.price * baskets_count * basket_quantity")
  end

  def total_pledged_value
    @total_pledged_value ||= pledges.includes(:membership).sum(&:total_membership_price)
  end

  def total_pledged_percentage
    return 0 if total_expected_value.zero?

    ((total_pledged_value / total_expected_value) * 100).round(2)
  end

  def pledges_count
    pledges.count
  end

  def missing_pledges_count
    eligible_memberships_count - pledges_count
  end

  def missing_pledges_percentage
    return 0 if eligible_memberships_count.zero?

    ((missing_pledges_count.to_f / eligible_memberships_count) * 100).round(2)
  end

  def average_pledge_amount
    return 0 if pledges_count.zero?

    pledges.average(:basket_price).to_f
  end

  def eligible_memberships
    Membership.during_year(fiscal_year)
  end

  def eligible_memberships_count
    @eligible_memberships_count ||= eligible_memberships.count
  end

  def can_create?
    self.class.draft.none? && eligible_memberships_count.positive?
  end

  def can_open?
    self.class.open.none? && eligible_memberships_count.positive?
  end

  def can_complete?
    open?
  end

  def can_fail?
    open?
  end

  def open!
    return unless can_open?

    update!(state: "open")
    # TODO: Send "Bidding Round Open" emails to all eligible members
    # BiddingRoundMailer.open_notification(self).deliver_later
  end

  def complete!
    return unless can_complete?

    transaction do
      update!(state: "completed")
      apply_pledges_to_memberships!
      # TODO: Send "Bidding Round Completed" emails
      # BiddingRoundMailer.completed_notification(self).deliver_later
    end
  end

  def fail!
    return unless can_fail?

    update!(state: "failed")
    # TODO: Send "Bidding Round Failed" emails (optional)
    # BiddingRoundMailer.failed_notification(self).deliver_later
  end

  def member_has_pledged?(membership)
    pledges.exists?(membership: membership)
  end

  private

  def set_number
    self.number = self.class.during_year(fy_year).maximum(:number).to_i + 1
  end

  # TODO: Move to async job?
  def apply_pledges_to_memberships!
    pledges.includes(:membership).each do |pledge|
      pledge.membership&.update!(basket_price: pledge.basket_size_price)
    end
  end

  def fiscal_year_must_be_current_or_future
    return unless fiscal_year

    if fiscal_year < Current.fiscal_year
      errors.add(:fiscal_year, :invalid)
    end
  end

  def only_one_draft
    return unless draft?

    if self.class.draft.where.not(id: id).exists?
      errors.add(:fiscal_year, :invalid)
    end
  end

  def only_one_open
    return unless open?

    if self.class.open.where.not(id: id).exists?
      errors.add(:fiscal_year, :invalid)
    end
  end

  def memberships_must_exist_for_fiscal_year
    return unless fiscal_year

    if eligible_memberships_count.zero?
      errors.add(:fiscal_year, :invalid)
    end
  end
end
