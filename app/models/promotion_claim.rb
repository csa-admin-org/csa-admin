# frozen_string_literal: true

class PromotionClaim < ApplicationRecord
  include TranslatedAttributes
  include HasPublicName

  class Error < StandardError; end
  class NotRedeemable < Error; end

  EXPIRY = 1.year

  belongs_to :promotion
  belongs_to :member
  belongs_to :membership, optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :expires_on, presence: true

  before_validation :set_expires_on, on: :create

  scope :not_voided, -> { where(voided_at: nil) }
  scope :voided, -> { where.not(voided_at: nil) }
  scope :unexpired, ->(on = Date.current) { where("expires_on >= ?", on) }
  # Counts toward max_uses: not voided and not past expires_on.
  scope :occupying, ->(on = Date.current) { not_voided.unexpired(on) }

  def self.live_for(member, on: Date.current)
    return none unless member

    occupying(on).where(member: member)
  end

  # Creates or replaces the member's live claim. The previous live row is
  # voided only after this code is redeemable. A failed call leaves it.
  def self.claim!(member, code, membership: nil)
    raise ArgumentError, "member required" unless member&.persisted?
    raise ArgumentError, "code required" unless code

    transaction do
      locked_code = Promotion.lock.find(code.id)
      unless Promotion.acceptable_target?(member, membership) && locked_code.redeemable?
        raise NotRedeemable
      end

      reused = reusable_claim(member, locked_code, membership)
      live = live_for(member).lock.first
      live.void! if live && live != reused

      if reused
        reused.reapply!(locked_code)
        reused
      else
        create!(
          promotion: locked_code,
          member: member,
          membership: membership,
          amount: locked_code.amount,
          commitment_required: locked_code.commitment_required,
          names: locked_code[:names],
          public_names: locked_code[:public_names])
      end
    end
  end

  def self.reusable_claim(member, code, membership)
    return unless membership

    member.promotion_claims.lock.find_by(promotion: code, membership: membership)
  end
  private_class_method :reusable_claim

  def voided?
    voided_at.present?
  end

  def expired?(on = Date.current)
    expires_on < on
  end

  # Pending is the default. Applied starts once the claim sits on a membership
  # that is no longer trial-only.
  def on_committed_membership?
    membership.present? && !membership.trial_only?
  end

  def occupying?(on = Date.current)
    !voided? && !expired?(on)
  end

  # Campaign state and period are not consulted. A saved claim lowers the
  # membership amount until it is voided or expired, including a trial-only
  # membership. Commitment voids it later, if that membership ends in trial.
  def billable?(on: Date.current)
    return false if voided? || expired?(on)

    membership.present?
  end

  def void!
    return if voided?

    update!(voided_at: Time.current)
  end

  # The same promotion on the same membership keeps this row.
  def reapply!(code)
    update!(
      voided_at: nil,
      amount: code.amount,
      commitment_required: code.commitment_required,
      names: code[:names],
      public_names: code[:public_names],
      expires_on: Date.current + EXPIRY,
      benefit_amount: nil)
  end

  def attach!(membership)
    update!(membership: membership)
    recompute_benefit_amount!
  end

  def release!(membership)
    return unless membership_id == membership.id

    update!(membership_id: nil, benefit_amount: nil)
  end

  def recompute_benefit_amount!
    return if membership.nil?
    return update!(benefit_amount: nil) unless billable?

    gross = membership.price_before_reduction - membership.price_reduction_amount.to_d
    amount = compute_benefit_amount(gross)
    update!(benefit_amount: amount)
    amount
  end

  # gross is the membership amount before this promotion.
  def compute_benefit_amount(gross)
    return unless membership
    return 0 if gross.nil? || gross <= 0

    [ amount.to_d, gross ].min
  end

  private

  def set_expires_on
    self.expires_on ||= Date.current + EXPIRY
  end
end
