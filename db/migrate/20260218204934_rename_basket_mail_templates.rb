# frozen_string_literal: true

class RenameBasketMailTemplates < ActiveRecord::Migration[8.1]
  RENAMES = {
    "membership_initial_basket" => "basket_initial",
    "membership_final_basket" => "basket_final",
    "membership_first_basket" => "basket_first",
    "membership_last_basket" => "basket_last",
    "membership_second_last_trial_basket" => "basket_second_last_trial",
    "membership_last_trial_basket" => "basket_last_trial"
  }.freeze

  def up
    RENAMES.each do |old_title, new_title|
      execute <<~SQL
        UPDATE mail_templates SET title = '#{new_title}' WHERE title = '#{old_title}'
      SQL
    end
  end

  def down
    RENAMES.each do |old_title, new_title|
      execute <<~SQL
        UPDATE mail_templates SET title = '#{old_title}' WHERE title = '#{new_title}'
      SQL
    end
  end
end
