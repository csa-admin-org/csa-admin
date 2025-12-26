# frozen_string_literal: true

# Handles entity type classification for invoices.
# Invoices can be linked to different entity types (Membership, Share, Shop::Order, etc.)
# and this concern provides predicates and scopes for working with these types.
module Invoice::EntityType
  extend ActiveSupport::Concern

  included do
    belongs_to :entity, polymorphic: true, optional: true, touch: true

    scope :membership, -> { where(entity_type: "Membership") }
    scope :share, -> { where(entity_type: "Share") }
    scope :shop_order_type, -> { where(entity_type: "Shop::Order") }
    scope :activity_participation_type, -> { where(entity_type: "ActivityParticipation") }
    scope :other_type, -> { where(entity_type: "Other") }
    scope :new_member_fee_type, -> { where(entity_type: "NewMemberFee") }
    scope :membership_eq, ->(membership) { where(entity: membership) }
    scope :same_entity, ->(invoice) { where(member_id: invoice.member_id, entity: invoice.entity) }
    scope :annual_fee, -> { where.not(annual_fee: nil) }

    validates :entity_type, inclusion: { in: proc { Invoice.entity_types } }
  end

  class_methods do
    def entity_types
      types = %w[Membership Other]
      types << "ActivityParticipation"
      types << "Shop::Order"
      types << "AnnualFee"
      types << "Share"
      types << "NewMemberFee"
      types
    end

    def used_entity_types
      types = %w[Membership Other]
      types << "ActivityParticipation" if Current.org.feature?("activity")
      types << "Shop::Order" if Current.org.feature?("shop")
      types << "AnnualFee" if Current.org.annual_fee?
      types << "Share" if Current.org.share?
      types << "NewMemberFee" if Current.org.feature?("new_member_fee")
      types += pluck(:entity_type)
      types.uniq.sort
    end
  end

  def membership_type?
    entity_type == "Membership"
  end

  def activity_participation_type?
    entity_type == "ActivityParticipation"
  end

  def share_type?
    entity_type == "Share"
  end

  def shop_order_type?
    entity_type == "Shop::Order"
  end

  def other_type?
    entity_type == "Other"
  end

  def new_member_fee_type?
    entity_type == "NewMemberFee"
  end

  def entity_fy_year
    entity_id? ? entity&.fy_year : fy_year
  end
end
