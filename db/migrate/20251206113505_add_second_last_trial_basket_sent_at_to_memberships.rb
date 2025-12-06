# frozen_string_literal: true

class AddSecondLastTrialBasketSentAtToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :second_last_trial_basket_sent_at, :datetime
  end
end
