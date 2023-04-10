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
      if basket_size_ids.any?
        members = members.where(memberships: { basket_size_id: basket_size_ids })
      end
      if basket_complement_ids.any?
        members =
          members
            .joins(current_or_future_membership: :memberships_basket_complements)
            .where(memberships_basket_complements: { basket_complement_id: basket_complement_ids })
      end
      if depot_ids.any?
        members = members.where(memberships: { depot_id: depot_ids })
      end
      if deliveries_cycle_ids.any?
        members = members.where(memberships: { deliveries_cycle_id: deliveries_cycle_ids })
      end
      if renewal_state?
        members = members.merge(Membership.renewal_state_eq(renewal_state))
      end
      members
    end
  end
end
