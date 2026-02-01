# frozen_string_literal: true

class BiddingRound < ApplicationRecord
  include HasState
  include Auditable
  include TranslatedRichTexts

  has_states :draft, :open, :failed, :completed

  audited_attributes :state

  has_many :pledges, class_name: "BiddingRound::Pledge", dependent: :destroy
  has_many :memberships, through: :pledges

  translated_rich_texts :information_text

  after_initialize do
    self.fy_year ||= self.class.fiscal_year.year
    self.number ||= self.class.during_year(fy_year).maximum(:number).to_i + 1
  end

  validates :fiscal_year, presence: true
  validate :fiscal_year_must_be_current_or_future
  validate :only_one_draft
  validate :only_one_open
  validate :memberships_must_exist_for_fiscal_year

  scope :during_year, ->(year) {
    fy_year = Current.org.fiscal_year_for(year).year
    where(fy_year: fy_year)
  }

  def self.current_draft
    draft.first
  end

  def self.current_open
    open.first
  end

  def self.previous(round)
    return unless round

    self
      .where(fy_year: round.fy_year)
      .where("number < ?", round.number)
      .order(number: :desc)
      .first
  end

  def self.can_create?
    new.valid?
  end

  def self.fiscal_year
    year = Current.fy_year
    until Delivery.during_year(year).past.none?
      year += 1
    end
    Current.org.fiscal_year_for(year)
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

  def filename
    [
      model_name.human.downcase.dasherize.gsub(/'|\s/, "-"),
      fiscal_year.to_s,
      number
    ].join("-")
  end

  def total_expected_value
    return self[:total_expected_value] if closed? && self[:total_expected_value]

    @total_expected_value ||= eligible_memberships.sum(:price)
  end

  def total_final_value
    return self[:total_final_value] if closed? && self[:total_final_value]

    @total_final_value ||= total_expected_value + pledges.includes(:membership).sum(&:total_membership_price_difference)
  end

  def total_final_percentage
    return 0 if total_expected_value.zero?

    ((total_final_value / total_expected_value) * 100).round(2)
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

  def pledges_percentage
    return 0 if total_expected_value.zero?

    ((pledges_count.to_f / eligible_memberships_count) * 100).round(2)
  end

  def missing_pledges_percentage
    return 0 if eligible_memberships_count.zero?

    ((missing_pledges_count.to_f / eligible_memberships_count) * 100).round(2)
  end

  def average_pledge_amount
    return 0 if pledges_count.zero?

    pledges.average(:basket_size_price).to_f
  end

  def eligible?(member)
    eligible_memberships.exists?(member: member)
  end

  def pledged?(member)
    pledges.joins(:membership).exists?(memberships: { member: member })
  end

  def eligible_memberships
    Membership.during_year(fiscal_year).joins(:member).merge(Member.no_salary_basket)
  end

  def eligible_memberships_count
    return self[:eligible_memberships_count] if closed? && self[:eligible_memberships_count]

    @eligible_memberships_count ||= eligible_memberships.count
  end

  def can_open?
    draft? && self.class.open.none? && eligible_memberships_count.positive?
  end

  def can_complete?
    open?
  end

  def can_fail?
    open?
  end

  def closed?
    completed? || failed?
  end

  def can_update?
    !closed?
  end

  def can_destroy?
    draft?
  end

  def opened_by
    audits.find_change_of(:state, to: "open")&.actor
  end

  def opened_at
    audits.find_change_of(:state, to: "open")&.created_at
  end

  def open!
    return unless can_open?

    update!(state: "open")
    eligible_memberships.find_each do |membership|
      MailTemplate.deliver_later(:bidding_round_opened,
        bidding_round: self,
        membership: membership)
    end
  end

  def complete!
    return unless can_complete?

    update!(
      state: "completed",
      eligible_memberships_count: eligible_memberships_count,
      total_expected_value: total_expected_value,
      total_final_value: total_final_value)

    jobs = eligible_memberships.map { |m| CompletionJob.new(self, m) }
    ActiveJob.perform_all_later(jobs)
  end

  def fail!
    return unless can_fail?

    update!(
      state: "failed",
      eligible_memberships_count: eligible_memberships_count,
      total_expected_value: total_expected_value,
      total_final_value: total_final_value)

    eligible_memberships.find_each do |membership|
      MailTemplate.deliver_later(:bidding_round_failed,
        bidding_round: self,
        membership: membership)
    end
  end

  def member_has_pledged?(membership)
    pledges.exists?(membership: membership)
  end

  private

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
