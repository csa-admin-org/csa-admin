class AddMemberInformationTitles < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :member_information_titles, :jsonb, default: {}, null: false
  end
end
