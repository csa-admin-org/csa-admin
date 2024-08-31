# frozen_string_literal: true

class AddMemberFormModeToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :member_form_mode, :string, default: 'membership', null: false
    rename_column :acps, :membership_extra_text_only, :member_form_extra_text_only

    reversible do |dir|
      dir.up do
        if Tenant.inside?
          org = Organization.find_by!(tenant_name: Tenant.current)
          if org.membership_extra_texts.present?
            org.member_form_extra_texts = org.membership_extra_texts
            org.save!
          end
        end
      end
    end
  end
end
