# frozen_string_literal: true

class Newsletter
  class Segment < ApplicationRecord
    self.table_name = "newsletter_segments"

    include TranslatedAttributes

    MEMBERSHIP_SCOPES = %w[current_or_future current future].freeze

    translated_attributes :title

    validates :membership_scope,
      inclusion: { in: MEMBERSHIP_SCOPES, allow_blank: true }
    validates :renewal_state,
      inclusion: { in: Membership::Renewal::STATES, allow_blank: true }
    validates :coming_deliveries_in_days,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_blank: true }

    validate :member_ids_must_be_exclusive

    def newsletters
      Newsletter.segment_eq(id)
    end

    def basket_complement_ids=(ids)
      super ids.map(&:presence).compact.map(&:to_i)
    end

    def basket_size_ids=(ids)
      super ids.map(&:presence).compact.map(&:to_i)
    end

    def delivery_cycle_ids=(ids)
      super ids.map(&:presence).compact.map(&:to_i)
    end

    def depot_ids=(ids)
      super ids.map(&:presence).compact.map(&:to_i)
    end

    def member_ids=(ids)
      super ids.to_s.split(",").map(&:strip).map(&:presence).compact.map(&:to_i).uniq.sort
    end

    def member_ids
      super.join(", ")
    end

    # Rails form helpers use `_before_type_cast` to render input values after
    # a validation error. For JSON array columns, this returns the raw Array
    # which gets joined with spaces in the HTML value attribute, losing commas.
    def member_ids_before_type_cast
      member_ids
    end

    def name; title end

    def members
      if self[:member_ids].any?
        members = Member.where(id: self[:member_ids])
      elsif membership_scope.present?
        members = Member.joins(membership_join_name)
        members = by_basket_size(members)
        members = by_basket_complement(members)
        members = by_depot(members)
        members = by_delivery_cycle(members)
        members = by_renewal_state(members)
        members = by_first_membership(members)
        members = by_billing_year_division(members)
        members = by_coming_deliveries_in_days(members)
      else
        members = Member.all
      end

      members = by_city(members)
      members = by_member_state(members)
      members.uniq
    end

    private

    def by_basket_size(members)
      return members unless basket_size_ids.any?

      members.where(memberships: { basket_size_id: basket_size_ids })
    end

    def by_basket_complement(members)
      return members unless basket_complement_ids.any?

      members
        .joins(membership_join_name => :memberships_basket_complements)
        .where(memberships_basket_complements: { basket_complement_id: basket_complement_ids })
    end

    def by_depot(members)
      return members unless depot_ids.any?

      members.where(memberships: { depot_id: depot_ids })
    end

    def by_delivery_cycle(members)
      return members unless delivery_cycle_ids.any?

      members.where(memberships: { delivery_cycle_id: delivery_cycle_ids })
    end

    def by_renewal_state(members)
      return members unless renewal_state?

      members.merge(Membership.renewal_state_eq(renewal_state))
    end

    def by_first_membership(members)
      return members if first_membership.nil?

      if first_membership
        members.where(memberships_count: 1)
      else
        members.where(memberships_count: 2..)
      end
    end

    def by_billing_year_division(members)
      return members unless billing_year_division?

      members.where(memberships: { billing_year_division: billing_year_division })
    end

    def by_coming_deliveries_in_days(members)
      return members unless coming_deliveries_in_days?

      limit = coming_deliveries_in_days.days.from_now
      members
        .joins(next_basket: :delivery)
        .where(deliveries: { date: ..limit })
    end

    def by_city(members)
      return members unless city?

      members.where(city: city)
    end

    def by_member_state(members)
      return members unless member_state.present?

      members.where(state: member_state)
    end

    def membership_join_name
      case membership_scope
      when "current" then :current_membership
      when "future" then :future_membership
      else :current_or_future_membership
      end
    end

    private

    def member_ids_must_be_exclusive
      return unless self[:member_ids].any?

      has_blocking_criteria =
        member_state.present?
        || city.present?
        || basket_size_ids.any?
        || basket_complement_ids.any?
        || depot_ids.any?
        || delivery_cycle_ids.any?
        || renewal_state.present?
        || !first_membership.nil?
        || coming_deliveries_in_days.present?
        || billing_year_division.present?

      if has_blocking_criteria
        errors.add(:member_ids, :exclusive)
      end
    end
  end
end
