class Newsletter
  class Segment < ApplicationRecord
    self.table_name = 'newsletter_segments'

    include TranslatedAttributes

    translated_attributes :title

    default_scope { order_by_title }

    validates :renewal_state,
      inclusion: { in: Membership::RENEWAL_STATES, allow_blank: true }

    def name; title end

    def members
      members = Member.joins(:current_or_future_membership)
      members = by_basket_size(members)
      members = by_basket_complement(members)
      members = by_depot(members)
      members = by_deliveries_cycle(members)
      members = by_renewal_state(members)
      members = by_first_membership(members)
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

    def by_deliveries_cycle(members)
      return members unless deliveries_cycle_ids.any?

      members.where(memberships: { deliveries_cycle_id: deliveries_cycle_ids })
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
  end
end
