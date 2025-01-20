# frozen_string_literal: true

class TrialBasketsCountToNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :members, :trial_baskets_count, false
  end
end
