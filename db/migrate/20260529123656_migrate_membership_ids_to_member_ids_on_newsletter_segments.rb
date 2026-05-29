# frozen_string_literal: true

class MigrateMembershipIdsToMemberIdsOnNewsletterSegments < ActiveRecord::Migration[8.1]
  def up
    Tenant.switch_each do
      Newsletter::Segment.where.not("membership_ids = ?", "[]").find_each do |segment|
        membership_ids = segment[:membership_ids] || []
        next if membership_ids.empty?

        member_ids = Membership.where(id: membership_ids).pluck(:member_id).uniq.sort

        segment.update_columns(
          member_ids: member_ids,
          membership_ids: [],
          membership_scope: nil,
          basket_size_ids: [],
          basket_complement_ids: [],
          depot_ids: [],
          delivery_cycle_ids: [],
          renewal_state: nil,
          first_membership: nil,
          coming_deliveries_in_days: nil,
          billing_year_division: nil,
          city: nil,
          member_state: nil)
      end
    end
  end

  def down
    # Irreversible data migration (we don't know which member_ids originally came from membership_ids)
    raise ActiveRecord::IrreversibleMigration
  end
end
