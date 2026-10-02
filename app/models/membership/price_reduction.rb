# frozen_string_literal: true

# One grant per membership. The cut is computed from the rule copied onto
# the grant, then subtracted from the membership price.
#
# A new grant that does not fit the remaining cap is dropped, unless the
# admin typed the rule (strict_cap), in which case the save fails.
# Later price writes clamp. They do not remove the grant and they do not
# recheck the depot or the card.
module Membership::PriceReduction
  extend ActiveSupport::Concern

  included do
    has_one :membership_price_reduction, dependent: :destroy, autosave: true
    has_one :price_reduction, through: :membership_price_reduction, class_name: "::PriceReduction"

    attr_accessor :price_reduction_skipped, :price_reduction_skip_reason, :selected_price_reduction_id

    accepts_nested_attributes_for :membership_price_reduction,
      allow_destroy: true,
      reject_if: :all_blank
  end

  def price_reduction_choice_id
    membership_price_reduction&.price_reduction_id unless membership_price_reduction&.marked_for_destruction?
  end

  def price_reduction_choice_id=(id)
    reduction = id.present? ? PriceReduction.kept.find_by(id: id) : nil
    if reduction.nil?
      clear_price_reduction!
    elsif membership_price_reduction&.price_reduction_id != reduction.id
      apply_price_reduction!(reduction, strict: true)
    end
  end

  def membership_price_reduction_attributes=(attrs)
    posted = attrs.to_h.with_indifferent_access
    super
    grant = membership_price_reduction
    return if grant.nil? || grant.marked_for_destruction?

    grant.posted_rule = posted.slice(*PriceReductionRule::FIELDS)
  end

  def apply_waiting_price_reduction!(member)
    reduction = member.waiting_price_reduction
    return unless reduction

    apply_price_reduction!(reduction)
  end

  def apply_price_reduction!(reduction, strict: false)
    return drop_price_reduction!(:feature) unless Current.org.feature?("price_reductions")
    return clear_price_reduction! unless reduction

    grant = membership_price_reduction || build_membership_price_reduction
    grant.price_reduction = reduction
    grant.snapshot_from_catalog
    grant.applying = true
    grant.strict_cap = strict
    grant
  end

  def clear_price_reduction!
    membership_price_reduction&.mark_for_destruction
    nil
  end

  def price_reduction_amount
    return 0 unless membership_price_reduction
    return 0 if membership_price_reduction.marked_for_destruction?

    membership_price_reduction.amount || 0
  end

  private

  def drop_price_reduction!(reason)
    clear_price_reduction!
    self.price_reduction_skipped = true
    self.price_reduction_skip_reason = reason
    nil
  end

  def sync_price_reduction!(enforce: false)
    grant = membership_price_reduction
    return if grant.nil? || grant.marked_for_destruction?
    return unless current_or_future_year?

    if member.salary_basket?
      if enforce && grant.applying && !grant_applicable?(grant, 0)
        refuse_grant!(grant, 0)
      else
        write_grant_amount!(grant, 0)
      end
      return
    end

    gross = price_before_reduction
    refused = grant.applying && !grant_applicable?(grant, gross)
    refused ||= grant.strict_cap && !grant.fits?(gross)
    if enforce && refused
      refuse_grant!(grant, gross)
      return
    end

    write_grant_amount!(grant, grant.clamped_amount(gross))
  end

  def strict_refusal_error(grant, gross)
    case grant_skip_reason(grant, gross)
    when :depot then :price_reduction_depot
    when :card then :price_reduction_card
    when :discarded then :price_reduction_discarded
    else :price_reduction_exceeds_cap
    end
  end

  def refuse_grant!(grant, gross)
    if grant.strict_cap
      errors.add(:price_reduction, strict_refusal_error(grant, gross))
      raise ActiveRecord::RecordInvalid, self
    end

    drop_applied_grant!(grant, gross)
  end

  def grant_applicable?(grant, gross)
    grant_skip_reason(grant, gross).nil?
  end

  def grant_skip_reason(grant, gross)
    reduction = grant.price_reduction
    return :discarded unless reduction

    reduction.skip_reason(
      gross,
      depot: depot,
      year: fy_year,
      member: member,
      on: started_on || Date.current,
      excluding: grant.persisted? ? grant : nil,
      amount: grant.raw_amount(gross))
  end

  def drop_applied_grant!(grant, gross)
    reason = grant_skip_reason(grant, gross)
    grant.destroy! if grant.persisted?
    self.membership_price_reduction = nil
    self.price_reduction_skipped = true
    self.price_reduction_skip_reason = reason || :cap
  end

  def write_grant_amount!(grant, amount)
    return if grant.amount == amount

    if grant.persisted?
      grant.update_columns(amount: amount, updated_at: Time.current)
    else
      grant.amount = amount
    end
  end
end
