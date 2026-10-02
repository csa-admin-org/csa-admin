# frozen_string_literal: true

class PriceReduction < ApplicationRecord
  CAP_MODES = %w[once fiscal_year].freeze

  include TranslatedAttributes
  include HasPublicName
  include HasVisibility
  include Discardable
  include PriceReductionRule
  include NumbersHelper

  translated_attributes :form_detail

  belongs_to :price_reduction_card, optional: true
  has_many :membership_price_reductions, dependent: :restrict_with_exception
  has_many :memberships, through: :membership_price_reductions
  has_many :waiting_members,
    class_name: "Member",
    foreign_key: :waiting_price_reduction_id,
    dependent: :nullify

  attribute :depot_ids, default: -> { [] }
  attribute :cap_mode, default: "once"

  validates :cap_mode, inclusion: { in: CAP_MODES }
  validates :cap_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :member_order_priority, numericality: { only_integer: true }, presence: true
  validate :cap_covers_granted
  validate :depot_ids_exist

  scope :member_ordered, -> { order(:member_order_priority).order_by_name }
  scope :for_depot, ->(depot) {
    id = depot.respond_to?(:id) ? depot.id : depot
    where("depot_ids = '[]' OR EXISTS (SELECT 1 FROM json_each(depot_ids) WHERE json_each.value = ?)", id)
  }

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[for_depot]
  end

  # Public forms only offer visible programs. A posted id of a hidden one is dropped,
  # and only that program's card fields are kept. The registration form posts cards as an array.
  def self.scope_public_params(permitted, reduction_key)
    reduction = visible.kept.find_by(id: permitted[reduction_key])
    permitted[reduction_key] = reduction&.id
    cards = permitted[:member_cards_attributes]
    return permitted if cards.blank?

    card_id = reduction&.price_reduction_card_id&.to_s
    permitted[:member_cards_attributes] =
      if cards.is_a?(Array)
        cards.select { |attrs| public_card?(attrs, card_id) }
      else
        cards.select { |_index, attrs| public_card?(attrs, card_id) }
      end
    permitted
  end

  def self.public_card?(attrs, card_id)
    posted = attrs[:price_reduction_card_id] || attrs["price_reduction_card_id"]
    card_id.present? && posted.to_s == card_id
  end
  private_class_method :public_card?

  def can_delete?
    membership_price_reductions.none? && waiting_members.none?
  end

  def can_discard?
    membership_price_reductions.none?
  end

  def depot_ids=(ids)
    super Array(ids).map(&:presence).compact.map(&:to_i).uniq
  end

  def depots
    return Depot.none if depot_ids.blank?

    Depot.where(id: depot_ids)
  end

  def all_depots?
    depot_ids.blank?
  end

  def depot_allowed?(depot)
    return true if all_depots?

    id = depot.respond_to?(:id) ? depot.id : depot
    id.present? && depot_ids.include?(id.to_i)
  end

  def capped?
    cap_amount.present?
  end

  def fiscal_year_cap?
    cap_mode == "fiscal_year"
  end

  def granted_amount(year = nil, excluding: nil)
    rel = membership_price_reductions
    rel = rel.where.not(id: excluding.id) if excluding
    if year && fiscal_year_cap?
      rel = rel.joins(:membership).merge(Membership.during_year(year))
    end
    rel.sum(:amount)
  end

  def remaining_amount(year = nil, excluding: nil)
    return nil unless capped?

    cap_amount - granted_amount(year, excluding: excluding)
  end

  def applicable_to?(gross, depot:, year:, member:, on: Date.current, excluding: nil)
    skip_reason(gross, depot: depot, year: year, member: member, on: on, excluding: excluding).nil?
  end

  def card_valid_for?(member, on = Date.current)
    return true unless price_reduction_card_id

    member&.member_card_for(price_reduction_card)&.valid_on?(on) || false
  end

  # amount is the cut already computed from a copied grant. Without it, the
  # catalog rule is used. excluding keeps a grant from counting against itself.
  def skip_reason(gross, depot:, year:, member:, on: Date.current, excluding: nil, amount: nil)
    return :discarded if discarded?
    return :depot unless depot_allowed?(depot)
    return :card unless card_valid_for?(member, on)
    return :rule unless percentage.present? ^ fixed_amount.present?

    cut = amount || raw_amount(gross)
    return :cap if capped? && cut > remaining_amount(year, excluding: excluding).to_d

    nil
  end

  def placeholder_form_detail
    parts = [ rule_label ]
    if price_reduction_card
      parts << I18n.t("price_reductions.form_detail.card",
        type: PriceReductionCard.model_name.human,
        card: price_reduction_card.name)
    end
    parts << I18n.t("price_reductions.form_detail.depots") unless all_depots?
    parts.compact_blank.join(", ")
  end

  def show_fiscal_years
    grant_years = memberships.distinct.pluck(:started_on).filter_map { |date|
      Current.org.fiscal_year_for(date)&.year
    }
    future_years = Current.org.fiscal_years.map(&:year).select { |year| year > Current.fy_year }
    future_years += Membership.distinct.pluck(:started_on).filter_map { |date|
      year = Current.org.fiscal_year_for(date)&.year
      year if year && year > Current.fy_year
    }
    (grant_years + [ Current.fy_year ] + future_years).uniq.sort.map { |year|
      Current.org.fiscal_year_for(year)
    }
  end

  def rule_label
    if percentage
      "#{percentage.to_s.sub(/\.0+\z/, "")}%"
    elsif fixed_amount
      cur(fixed_amount)
    end
  end

  private

  def cap_covers_granted
    return if cap_amount.blank?
    return if new_record? && membership_price_reductions.none?

    if fiscal_year_cap?
      granted_years.each do |year|
        granted = granted_amount(year)
        next if cap_amount >= granted

        errors.add(:cap_amount, :below_granted_year,
          year: Current.org.fiscal_year_for(year).to_s,
          granted: cur(granted))
      end
    else
      granted = granted_amount
      return if cap_amount >= granted

      errors.add(:cap_amount, :below_granted,
        granted: cur(granted))
    end
  end

  def granted_years
    memberships.where(started_on: Current.fy_range.min..).distinct.pluck(:started_on).map { |date|
      Current.org.fiscal_year_for(date).year
    }.uniq
  end

  def depot_ids_exist
    return if depot_ids.blank?
    return if Depot.where(id: depot_ids).count == depot_ids.size

    errors.add(:depot_ids, :invalid)
  end
end
