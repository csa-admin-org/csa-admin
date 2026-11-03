# frozen_string_literal: true

class AllowNullAbsenceOnBasketShifts < ActiveRecord::Migration[8.1]
  def change
    # A forced delivery is shifted without declaring an absence. The forced
    # delivery itself keeps the included-absence slot.
    change_column_null :basket_shifts, :absence_id, true
  end
end
