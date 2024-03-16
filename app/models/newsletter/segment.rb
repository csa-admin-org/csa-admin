class Newsletter
  class Segment < ApplicationRecord
    self.table_name = "newsletter_segments"

    include TranslatedAttributes

    translated_attributes :title

    default_scope { order_by_title }

    validates :renewal_state,
      inclusion: { in: Membership::RENEWAL_STATES, allow_blank: true }
    validates :coming_deliveries_in_days,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_blank: true }

    def name; title end

    def members
      members = Member.joins(:current_or_future_membership)
      members = by_basket_size(members)
      members = by_basket_complement(members)
      members = by_depot(members)
      members = by_delivery_cycle(members)
      members = by_renewal_state(members)
      members = by_first_membership(members)
      members = by_coming_deliveries_in_days(members)
      members = by_billing_year_division(members)
      members
    end

    private

    def by_basket_size(members)
      return members unless basket_size_ids.any?

      members.where(memberships: { basket_size_id: basket_size_ids })
    end

    def by_basket_complement(members)
      return members unless basket_complement_ids.any?

      members
        .joins(current_or_future_membership: :memberships_basket_complements)
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

    # TODO: Try to use an association here instead of select
    def by_coming_deliveries_in_days(members)
      return members unless coming_deliveries_in_days?

      limit = coming_deliveries_in_days.days.from_now
      members.includes(next_basket: :delivery).select { |m|
        m.next_basket && m.next_basket.delivery.date <= limit
      }
    end

    def by_billing_year_division(members)
      return members unless billing_year_division?

      members.where(memberships: { billing_year_division: billing_year_division })
    end
  end
end
