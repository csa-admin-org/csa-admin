# frozen_string_literal: true

class Promotion < ApplicationRecord
  include TranslatedAttributes
  include HasPublicName
  include Discardable

  STATES = %w[active archived].freeze
  TOKEN_LENGTH = 12

  has_many :promotion_claims, dependent: :restrict_with_exception
  has_many :waiting_members,
    class_name: "Member",
    foreign_key: :waiting_promotion_id,
    dependent: :nullify

  attr_readonly :code

  attribute :state, default: "active"
  attribute :commitment_required, :boolean, default: false

  validates :code, presence: true, uniqueness: true
  validates :state, inclusion: { in: STATES }
  validates :max_uses, inclusion: { in: [ nil, 1 ] }
  validates :amount, numericality: { greater_than: 0 }

  before_validation :generate_token, on: :create
  before_validation :clear_ends_on_when_archived
  validate :ends_on_not_past, if: :ends_on_changed?

  scope :kept, -> { undiscarded }
  scope :active, -> { where(state: "active") }
  scope :archived, -> { where(state: "archived") }
  scope :ended, ->(on = Date.current) {
    active.where("ends_on IS NOT NULL AND ends_on < ?", on)
  }
  scope :uses_eq, ->(count) { uses_compare("=", count) }
  scope :uses_gt, ->(count) { uses_compare(">", count) }
  scope :uses_lt, ->(count) { uses_compare("<", count) }

  def self.redeemable_on(date = Date.current)
    kept.active.where("ends_on IS NULL OR ends_on >= ?", date)
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[uses_eq uses_gt uses_lt]
  end

  def self.archive_ended!(on = Date.current)
    ended(on).find_each(&:archive!)
  end

  def self.find_redeemable_by_id(id, on: Date.current)
    found = redeemable_on(on).find_by(id: id)
    found if found&.uses_remaining?
  end

  def self.find_redeemable(code, on: Date.current)
    return if code.blank?

    found = redeemable_on(on).find_by("LOWER(code) = ?", code.to_s.strip.downcase)
    found if found&.uses_remaining?
  end

  def self.find_by_code(code)
    return if code.blank?

    kept.find_by("LOWER(code) = ?", code.to_s.strip.downcase)
  end

  def self.claimable
    redeemable_on.order_by_name
  end

  def self.uses_compare(operator, count)
    occupying = PromotionClaim.occupying.where("promotion_claims.promotion_id = promotions.id")
    where("(#{occupying.select("COUNT(*)").to_sql}) #{operator} ?", count.to_i)
  end
  private_class_method :uses_compare

  # A salary basket is not invoiced, so a claim would occupy the one discount
  # and pay nothing.
  def self.acceptable_target?(member, _membership = nil)
    return false if member.nil? || member.salary_basket?

    true
  end

  def max_uses_mode
    max_uses == 1 ? "unique" : "unlimited"
  end

  def max_uses_mode=(mode)
    self.max_uses = mode == "unique" ? 1 : nil
  end

  def archived?
    state == "archived"
  end

  def ended?(on = Date.current)
    ends_on.present? && ends_on < on
  end

  def redeemable?(on: Date.current)
    kept? && !archived? && !ended?(on) && uses_remaining?
  end

  def archive!
    update!(state: "archived")
  end

  def unarchive!
    update!(state: "active")
  end

  def uses_remaining?(excluding: nil)
    return true if max_uses.nil?

    occupying_count(excluding: excluding) < max_uses
  end

  def occupying_count(excluding: nil)
    rel = promotion_claims.occupying
    rel = rel.where.not(id: excluding.id) if excluding
    rel.count
  end

  def registration_url(request)
    Rails.application.routes.url_helpers.new_members_member_url(
      subdomain: Current.org.members_subdomain,
      ref: code,
      host: request.host_with_port,
      protocol: request.protocol)
  end

  def can_update?
    return false if archived?

    super
  end

  def can_delete?
    promotion_claims.none? && waiting_members.none?
  end

  # A claim keeps the snapshotted discount. Archive closes the link instead.
  def can_discard?
    false
  end

  private

  def generate_token
    return if code.present?

    self.code = loop do
      candidate = SecureRandom.hex(TOKEN_LENGTH / 2)
      break candidate unless self.class.exists?(code: candidate)
    end
  end

  def clear_ends_on_when_archived
    self.ends_on = nil if archived?
  end

  def ends_on_not_past
    return if ends_on.blank? || ends_on >= Date.current

    errors.add(:ends_on, :past)
  end
end
