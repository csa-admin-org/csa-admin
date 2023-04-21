class AddMemberFormModeToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :member_form_mode, :string, default: 'membership', null: false
    rename_column :acps, :membership_extra_text_only, :member_form_extra_text_only

    reversible do |dir|
      dir.up do
        if Tenant.inside?
          acp = ACP.find_by!(tenant_name: Tenant.current)
          if acp.membership_extra_texts.present?
            acp.member_form_extra_texts = acp.membership_extra_texts
            acp.save!
          end
        end
      end
    end
  end
end
