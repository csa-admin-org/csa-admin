# frozen_string_literal: true

class RenameAbsenceBasketsShiftedMailTemplate < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE mail_templates SET title = 'absence_baskets_shifted' WHERE title = 'absence_basket_shifted'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE mail_templates SET title = 'absence_basket_shifted' WHERE title = 'absence_baskets_shifted'
    SQL
  end
end
