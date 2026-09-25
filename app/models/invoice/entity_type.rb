# frozen_string_literal: true

module Invoice::EntityType
  extend ActiveSupport::Concern

  SHOP_ENTITY_TYPES = %w[Shop::Order Shop::OrderGroup].freeze

  included do
    belongs_to :entity, polymorphic: true, optional: true, touch: true

    scope :membership, -> { where(entity_type: "Membership") }
    scope :share, -> { where(entity_type: "Share") }
    scope :shop_order_type, -> { where(entity_type: SHOP_ENTITY_TYPES) }
    scope :entity_type_eq, ->(type) { where(entity_type: entity_types_for(type)) }
    scope :entity_type_in, ->(*types) {
      where(entity_type: Array(types).flatten.flat_map { |type| entity_types_for(type) })
    }
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
      types << "Shop::OrderGroup"
      types << "AnnualFee"
      types << "Share"
      types << "NewMemberFee"
      types
    end

    def used_entity_types
      types = %w[Membership Other]
      types << "ActivityParticipation" if Current.org.feature?("activity")
      types << "Shop::Order" if Current.org.feature?("shop")
      types << "AnnualFee" if Current.org.feature?("annual_fee")
      types << "Share" if Current.org.feature?("shares")
      types << "NewMemberFee" if Current.org.feature?("new_member_fee")
      types += pluck(:entity_type)
      types.uniq.sort - [ "Shop::OrderGroup" ]
    end

    def entity_types_for(type)
      type == "Shop::Order" ? SHOP_ENTITY_TYPES : type
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
    entity_type.in?(self.class::SHOP_ENTITY_TYPES)
  end

  def shop_order_group_type?
    entity_type == "Shop::OrderGroup"
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
