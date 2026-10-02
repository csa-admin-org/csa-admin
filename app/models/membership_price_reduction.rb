# frozen_string_literal: true

class MembershipPriceReduction < ApplicationRecord
  include PriceReductionRule

  belongs_to :membership
  belongs_to :price_reduction

  attr_accessor :strict_cap, :applying, :posted_rule

  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  before_validation :fill_blank_rule_from_catalog
  before_validation :strict_when_rule_changes

  def snapshot_from_catalog
    source = price_reduction
    return unless source

    self.percentage = source.percentage
    self.fixed_amount = source.fixed_amount
  end

  def fits?(gross)
    remaining = remaining_including_self
    remaining.nil? || raw_amount(gross) <= remaining
  end

  def clamped_amount(gross)
    raw = raw_amount(gross)
    remaining = remaining_including_self
    raw = [ raw, remaining ].min if remaining
    [ raw, 0 ].max
  end

  def remaining_including_self
    year = price_reduction.fiscal_year_cap? ? membership.fy_year : nil
    price_reduction.remaining_amount(year, excluding: persisted? ? self : nil)
  end

  private

  # A blank post means the catalog default.
  # A posted percentage or fixed amount is kept and does not copy the other side.
  def fill_blank_rule_from_catalog
    source = price_reduction
    return unless source
    return if marked_for_destruction?

    if posted_rule.nil?
      snapshot_from_catalog if should_snapshot? || price_reduction_id_changed?
      return
    end

    posted = posted_rule
    if posted[:percentage].present? || posted[:fixed_amount].present?
      self.percentage = posted[:percentage].presence
      self.fixed_amount = posted[:fixed_amount].presence
    else
      self.percentage = source.percentage
      self.fixed_amount = source.fixed_amount
    end
  end

  def should_snapshot?
    new_record? && percentage.blank? && fixed_amount.blank?
  end

  def strict_when_rule_changes
    return if new_record?
    return unless percentage_changed? || fixed_amount_changed?
    return if posted_rule && !posted_override?

    self.strict_cap = true
  end

  def posted_override?
    PriceReductionRule::FIELDS.any? { |field|
      posted_rule[field].present? && public_send(:"#{field}_changed?")
    }
  end
end
